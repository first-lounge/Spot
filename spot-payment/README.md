# Spot Payment Service

결제 승인, 취소, 환불을 담당하는 마이크로서비스입니다.
Toss Payments PG 연동, Temporal Workflow 기반 분산 트랜잭션(Saga), Kafka Outbox Pattern을 사용합니다.

---

## 기술 스택

| 항목 | 기술 |
|------|------|
| Language | Java 21 |
| Framework | Spring Boot 3.5.9 |
| Database | PostgreSQL, JPA/Hibernate |
| Workflow | Temporal 1.31.0 |
| Messaging | Apache Kafka (Outbox Pattern) |
| PG | Toss Payments API |
| Service 통신 | OpenFeign |
| Resilience | Resilience4j (Circuit Breaker, Retry, Bulkhead) |
| 모니터링 | Micrometer Prometheus |
| Container | Docker (Eclipse Temurin JRE 21) |

---

## 프로젝트 구조

```
spot-payment/src/main/java/com/example/Spot/payments/
├── application/service/
│   ├── command/              # PaymentApprovalService, PaymentCancellationService, BillingAuthService
│   ├── query/                # PaymentQueryService
│   ├── PaymentService.java   # Facade
│   ├── PaymentHistoryService.java
│   └── PaymentOutboxCleanupService.java
├── domain/
│   ├── entity/               # PaymentEntity, PaymentHistoryEntity, PaymentKeyEntity
│   │                         # PaymentOutboxEntity, UserBillingAuthEntity
│   ├── repository/           # 각 엔티티별 Repository
│   └── gateway/
│       └── PaymentGateway.java  # Toss API 추상화 인터페이스
└── infrastructure/
    ├── aop/                  # PaymentAspect, @Ready, @PaymentBillingApproveTrace, @Cancel
    ├── client/               # TossPaymentClient (implements PaymentGateway)
    ├── event/                # 발행/구독 이벤트 DTO
    ├── listener/             # PaymentListener (Kafka Consumer)
    ├── producer/             # PaymentEventProducer (Outbox)
    └── temporal/             # PaymentApproveWorkflow, PaymentCancelWorkflow, Activities
```

---

## 도메인 모델

```mermaid
erDiagram
    p_payment {
        UUID id PK
        INT user_id
        UUID order_id UK
        VARCHAR payment_title
        VARCHAR payment_content
        VARCHAR payment_method
        BIGINT payment_amount
        TIMESTAMP created_at
        INT created_by
    }

    p_payment_history {
        UUID id PK
        UUID payment_id FK
        VARCHAR payment_status
        TIMESTAMP created_at
        INT created_by
    }

    p_payment_key {
        UUID id PK
        UUID payment_id FK
        VARCHAR payment_key
        TIMESTAMP confirmed_at
        TIMESTAMP created_at
        INT created_by
    }

    p_payment_outbox {
        UUID id PK
        VARCHAR aggregate_type
        UUID aggregate_id
        VARCHAR event_type
        TEXT payload
        TIMESTAMP created_at
    }

    p_user_billing_auth {
        UUID id PK
        INT user_id
        VARCHAR auth_key
        VARCHAR customer_key
        VARCHAR billing_key
        TIMESTAMP issued_at
        BOOLEAN is_active
        TIMESTAMP created_at
        INT created_by
    }

    p_payment ||--o{ p_payment_history : "tracks status"
    p_payment ||--o{ p_payment_key : "confirmed by"
    p_payment ||--o{ p_payment_outbox : "publishes"
    p_user_billing_auth }o--|| p_payment : "used in"
```

---

## 결제 상태별 테이블 저장 순서

```mermaid
flowchart TD
    Start(["결제 요청 수신"]) --> R1

    subgraph READY_STEP["① READY"]
        R1[("p_payment<br/> 결제 정보 신규 등록")]
        R1 --> R2[("p_payment_history<br/>결제 정보 신규 상태 저장<br/>status=READY")]
    end

    READY_STEP --> IP[("p_payment_history<br/>결제 정보 상태 저장<br/>status=IN_PROGRESS")]

    subgraph INPROGRESS_STEP["② IN_PROGRESS"]
        IP --> WF["Toss API 호출<br/>POST /v1/billing/{billingKey}"]
    end

    INPROGRESS_STEP --> TOSS["Toss API 응답<br/>POST /v1/billing/{billingKey}"]

    subgraph DONE_STEP["③ DONE"]
        TOSS --> |성공| D1[("p_payment_history<br/>결제 정보 상태 저장<br/>status=DONE")]
        D1 --> D2[("p_payment_key<br/>결제 후 얻은 Payment Key 저장")]
        D2 --> D3[("p_payment_outbox<br/>결제 성공 저장")]
    end

    subgraph ABORTED_STEP["③ ABORTED (실패 시)"]
        TOSS -->|실패| A1[("p_payment_history<br/>결제 정보 상태 저장<br/>status=ABORTED")]
        A1 --> A2[("p_payment_outbox<br/>결제 실패 저장")]
    end

    style READY_STEP fill:#e8f4fd,stroke:#2196F3
    style INPROGRESS_STEP fill:#fff8e1,stroke:#FF9800
    style DONE_STEP fill:#e8f5e9,stroke:#4CAF50
    style ABORTED_STEP fill:#fce4ec,stroke:#F44336
```

> `p_payment_history`는 상태가 바뀔 때마다 **행이 추가(INSERT)**됩니다. UPDATE가 아닌 append-only 구조로 전체 이력이 보존됩니다.

---

## 결제 상태 흐름

```mermaid
stateDiagram-v2
    [*] --> READY : 주문 생성 이벤트 수신

    state FAILURE_HANDLING {
        ABORTED
        CANCEL_FAILED
    }

    READY --> IN_PROGRESS : Temporal Workflow 시작
    IN_PROGRESS --> DONE : Toss API 결제 성공
    IN_PROGRESS --> ABORTED : Toss API 결제 실패

    DONE --> CANCELLED_IN_PROGRESS : 취소 요청
    CANCELLED_IN_PROGRESS --> CANCELLED : Toss API 취소 성공
    CANCELLED_IN_PROGRESS --> CANCEL_FAILED : Toss API 취소 실패

    DONE --> PARTIAL_CANCELLED : 부분 취소

    note right of FAILURE_HANDLING
        compensation 실행
        auth-required 이벤트 발행
    end note

    note right of CANCELLED
        payment.refunded 이벤트 발행
    end note
```

---

## 결제 승인 플로우

```mermaid
sequenceDiagram
    participant Kafka as Kafka
    participant Listener as PaymentListener
    participant AOP as @Ready / @Trace AOP
    participant DB as PostgreSQL
    participant Temporal as PaymentApproveWorkflow
    participant Activity as PaymentActivities
    participant Toss as Toss Payments API
    participant Outbox as p_payment_outbox

    Kafka-->>Listener: order.created 이벤트
    Listener->>AOP: ready(PaymentRequestDto.Confirm)
    AOP->>DB: findByOrderId() - 중복 확인
    AOP->>DB: save(PaymentEntity) + history(READY)
    AOP-->>Listener: paymentId 반환
    Listener->>Temporal: startWorkflow(PaymentApproveWorkflow)

    Temporal->>Activity: recordStatus(IN_PROGRESS)
    Activity->>DB: history(IN_PROGRESS) 저장
    Temporal->>Activity: executePayment(paymentId)
    Activity->>DB: UserBillingAuthEntity 조회 (billingKey)
    Activity->>Toss: POST /v1/billing/{billingKey}
    Toss-->>Activity: 결제 성공 응답
    Activity->>DB: history(DONE) + PaymentKeyEntity 저장
    Temporal->>Activity: publishSucceeded(paymentId)
    Activity->>Outbox: PaymentSucceededEvent 저장
    Outbox-->>Kafka: payment.succeeded 발행
```

---

## 결제 취소/환불 플로우

```mermaid
sequenceDiagram
    participant Kafka as Kafka
    participant Listener as PaymentListener
    participant Temporal as PaymentCancelWorkflow
    participant Activity as PaymentActivities
    participant Toss as Toss Payments API
    participant DB as PostgreSQL
    participant Outbox as p_payment_outbox

    Kafka-->>Listener: order.cancelled 이벤트
    Listener->>Temporal: startWorkflow(PaymentCancelWorkflow)

    Temporal->>Activity: recordCancelProgress(paymentId)
    Activity->>DB: history(CANCELLED_IN_PROGRESS) 저장

    Temporal->>Activity: refundByOrderId(orderId, reason)
    Activity->>DB: PaymentKeyEntity 조회
    Activity->>Toss: POST /v1/payments/{paymentKey}/cancel
    Toss-->>Activity: 취소 성공 응답

    Temporal->>Activity: recordCancelSuccess(paymentId)
    Activity->>DB: history(CANCELLED) 저장

    Temporal->>Activity: publishRefundSucceeded(orderId)
    Activity->>Outbox: PaymentRefundedEvent 저장
    Outbox-->>Kafka: payment.refunded 발행

    Note over Temporal: 실패 시 역순으로 Compensation 실행
```

---

## Temporal Saga 보상 트랜잭션

```mermaid
flowchart TD
    Start[결제 시작] --> S1[recordStatus IN_PROGRESS]
    S1 --> S2[executePayment via Toss]
    S2 --> S3[publishSucceeded]
    S3 --> Done[완료]

    S1 -->|실패| C1[recordAborted]
    S2 -->|실패| C2[refundPayment]
    C2 --> C1
    C1 --> Fail[publishAuthRequired]

    subgraph Compensation["보상 트랜잭션 (역순 실행)"]
        C2
        C1
        Fail
    end
```

---

## AOP 상태 관리

```mermaid
graph TD
    subgraph AOP["PaymentAspect (AOP)"]
        R["@Ready<br/>PaymentApprovalService.ready()"]
        T["@PaymentBillingApproveTrace<br/>createPaymentBillingApprove()"]
        C["@Cancel<br/>PaymentCancellationService.executeCancel()"]
    end

    R -->|중복 있음| R1["기존 paymentId 반환 (멱등성)"]
    R -->|신규| R2["PaymentEntity 생성 + READY 기록"]

    T -->|진입| T1["history(IN_PROGRESS)"]
    T -->|성공| T2["history(DONE) + PaymentKey 저장"]
    T -->|실패| T3["history(ABORTED)"]

    C -->|진입| C1["history(CANCELLED_IN_PROGRESS)"]
    C -->|성공| C2["history(CANCELLED)"]
    C -->|실패| C3["history(ABORTED)"]
```

---

## Outbox Pattern 이벤트 흐름

```mermaid
graph LR
    subgraph Published["Payment 서버 → Kafka"]
        E1["결제 처리 완료"]
        E2["결제 환불 완료"]
    end

    subgraph Subscribed["Kafka → Payment 서버"]
        E4["결제 요청"]
        E5["결제 취소 요청"]
    end

    Outbox["p_payment_outbox<br/>(Outbox Pattern)"] --> E1 & E2
    E4 --> L1["결제 로직 시작"]
    E5 --> L2["결제 취소 로직 시작"]

    Cleanup["매일 03:00, 7일 이상 지난<br/> 데이터 삭제"] -.->|cleanup| Outbox
```

---

## Resilience4j — Toss Payments 장애 격리

`TossPaymentClient`의 모든 Toss API 호출에 **Circuit Breaker + Bulkhead + Retry** 3중 보호가 적용됩니다.

### 적용 위치

| 인스턴스명 | 적용 메서드 | Toss API |
|-----------|------------|----------|
| `toss_billing_payment` | `requestBillingPayment()` | `POST /v1/billing/{billingKey}` |
| `toss_payment_cancel` | `cancelPayment()` | `POST /v1/payments/{paymentKey}/cancel` |
| `toss_payment_partial_cancel` | `cancelPaymentPartial()` | `POST /v1/payments/{paymentKey}/cancel` |
| `toss_billing_key_issue` | `issueBillingKey()` | `POST /v1/billing/authorizations/issue` |

```java
// TossPaymentClient.java 실제 적용 예시
@CircuitBreaker(name = "toss_billing_payment")
@Bulkhead(name = "toss_billing_payment", type = Bulkhead.Type.SEMAPHORE)
@Retry(name = "toss_billing_payment")
public TossPaymentResponse requestBillingPayment(...) { ... }
```

### 각 패턴의 역할

```mermaid
flowchart LR
    Activity["PaymentActivities<br/>(Temporal)"] --> Retry

    subgraph R4J["Resilience4j"]
        direction LR
        Retry["Retry<br/>실패 시 재시도"] --> CB["Circuit Breaker<br/>연속 실패 시 차단"]
        CB --> BH["Bulkhead<br/>동시 요청 수 제한"]
    end

    BH --> Toss["Toss Payments API"]

    CB -->|OPEN 상태| Fallback["즉시 예외 반환<br/>(Temporal이 재시도 처리)"]
```

### Circuit Breaker 상태 전환

```mermaid
stateDiagram-v2
    [*] --> CLOSED : 초기 상태

    CLOSED --> OPEN : 실패율 임계치 초과
    note right of CLOSED
        Toss API 정상 호출
        실패 횟수 카운팅
    end note

    OPEN --> HALF_OPEN : 대기 시간 경과 후 일부 요청 허용
    note right of OPEN
        모든 요청 즉시 차단
    end note

    HALF_OPEN --> CLOSED : 테스트 요청 성공
    HALF_OPEN --> OPEN : 테스트 요청 실패
```

### Temporal과의 연동

Circuit Breaker가 `OPEN` 상태일 때 Toss API 호출이 차단되면,
Temporal Activity가 예외를 받아 **자체 재시도 스케줄러**로 넘깁니다.

```
Toss API 장애 발생
    → Circuit Breaker OPEN (즉시 차단)
    → Temporal Activity 실패
    → Temporal 재시도 (초기 10초 → 최대 1분 간격, 최대 6회)
    → Circuit Breaker HALF_OPEN 전환 후 복구 감지
    → 결제 재시도 성공
```

Resilience4j와 Temporal의 재시도가 **이중으로** 동작하여,
단순 네트워크 순단은 Resilience4j Retry가, 장시간 장애는 Temporal이 처리합니다.

---

## 외부 서비스 연동 (Feign)

```mermaid
graph LR
    subgraph PaymentService["Spot Payment Service"]
        OC[OrderClient]
        SC[StoreClient]
        UC[UserClient]
    end

    OC -->|"GET /api/internal/orders/{orderId}"| OS["Spot Order Service"]
    OC -->|"GET /api/internal/orders/{orderId}/exists"| OS

    SC -->|"GET /api/internal/store-users/exists"| SS["Spot Store Service"]
    SC -->|"GET /api/internal/store-users/by-user"| SS

    UC -->|"GET /api/internal/users/{userId}"| US["Spot User Service"]
    UC -->|"GET /api/internal/users/{userId}/exists"| US
```

---

## API 엔드포인트

### 결제 (`/api/payments`)

| Method | Path | 권한 | 설명 |
|--------|------|------|------|
| POST | `/api/payments/{orderId}/confirm` | CUSTOMER/OWNER/MANAGER/MASTER | 결제 승인 실행 |
| POST | `/api/payments/{orderId}/cancel` | CUSTOMER/OWNER/MANAGER/MASTER | 결제 취소 |
| GET | `/api/payments` | MANAGER/MASTER | 전체 결제 목록 |
| GET | `/api/payments/{paymentId}` | CUSTOMER/OWNER/MANAGER/MASTER | 결제 상세 조회 |
| GET | `/api/payments/cancel` | MANAGER/MASTER | 전체 취소 목록 |
| GET | `/api/payments/{paymentId}/cancel` | CUSTOMER/OWNER/MANAGER/MASTER | 결제별 취소 내역 |
| POST | `/api/payments/billing-key` | 없음 | 빌링키 등록 (authKey → billingKey) |
| GET | `/api/payments/billing-key/exists` | CUSTOMER/OWNER/MANAGER/MASTER | 빌링키 보유 여부 |
| POST | `/api/payments/history` | CUSTOMER/OWNER/MANAGER/MASTER | FE 콜백 결제 이력 저장 |

### Internal (서비스 간 통신)

| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/internal/payments/order/{orderId}` | 주문 ID로 결제 조회 |
| GET | `/api/internal/payments/order/{orderId}/exists` | 활성 결제 존재 여부 |
| POST | `/api/internal/payments/{paymentId}/cancel` | 내부 결제 취소 |

---

## Temporal Workflow 설정

| 항목 | PaymentApproveWorkflow | PaymentCancelWorkflow |
|------|------------------------|----------------------|
| Task Queue | PAYMENT_TASK_QUEUE | PAYMENT_TASK_QUEUE |
| Workflow ID | `payment-wf-{orderId}` | `cancel-wf-{orderId}` |
| 초기 재시도 간격 | 10초 | 5초 |
| 최대 재시도 간격 | 1분 | 3분 |
| 최대 시도 횟수 | 6회 | 15회 (환불은 더 관대) |
| 재시도 제외 예외 | BillingKeyNotFoundException | BillingKeyNotFoundException |
| ID 재사용 정책 | ALLOW_DUPLICATE_FAILED_ONLY | ALLOW_DUPLICATE_FAILED_ONLY |

---

## 주요 설계 패턴

| 패턴 | 적용 위치 | 목적 |
|------|-----------|------|
| Outbox Pattern | PaymentOutboxEntity + PaymentEventProducer | 이벤트 발행 신뢰성 보장 |
| Saga Pattern | Temporal Workflow + Compensation | 분산 트랜잭션 일관성 |
| Idempotency | @Ready AOP + Temporal ID 정책 | 중복 결제 방지 |
| Circuit Breaker | Resilience4j (Toss, User) | 외부 서비스 장애 격리 |
| AOP | PaymentAspect | 상태 전환 횡단 관심사 분리 |
| CQRS | command/ vs query/ 분리 | 읽기/쓰기 책임 분리 |
| Gateway | PaymentGateway 인터페이스 | PG사 교체 용이성 확보 |

---

## 실행 환경

- **Port**: 8084 (기본)
- **Docker**: `eclipse-temurin:21-jre` 기반
- **외부 설정**: `/config/` 디렉터리의 `common.yml`, `kafka-topics.yml`, `spot-payment.yml`
- **Outbox 정리**: 매일 03:00, 7일 이상 된 레코드 자동 삭제
