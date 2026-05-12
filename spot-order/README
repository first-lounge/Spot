# Spot Order Service

주문 생성부터 완료/취소까지의 전체 라이프사이클을 관리하는 마이크로서비스입니다.
Temporal Workflow를 통한 분산 트랜잭션, Kafka Outbox Pattern 기반 이벤트 발행, Feign 기반 서비스 간 통신을 사용합니다.

---

## 기술 스택

| 항목 | 기술 |
|------|------|
| Language | Java 21 |
| Framework | Spring Boot 3.5.9 |
| Database | PostgreSQL, JPA/Hibernate |
| Workflow | Temporal 1.31.0 |
| Messaging | Apache Kafka (Outbox Pattern) |
| Service 통신 | OpenFeign |
| Cache | Redis |
| 인증 | JWT |
| Resilience | Resilience4j (Circuit Breaker, Retry, Bulkhead) |
| 모니터링 | Micrometer Prometheus |
| Container | Docker (Eclipse Temurin JRE 21) |

---

## 프로젝트 구조

```
spot-order/src/main/java/com/example/Spot/
├── SpotOrderApplication.java
├── order/
│   ├── domain/
│   │   ├── entity/          # JPA 엔티티
│   │   ├── enums/           # OrderStatus, CancelledBy
│   │   ├── exception/       # 도메인 예외
│   │   └── repository/      # JPA 레포지토리
│   ├── application/
│   │   └── service/         # OrderService, OrderServiceImpl
│   ├── infrastructure/
│   │   ├── temporal/        # Workflow & Activity
│   │   ├── event/           # 발행/구독 이벤트 DTO
│   │   ├── producer/        # Kafka 이벤트 발행
│   │   ├── listener/        # Kafka 이벤트 수신
│   │   └── aop/             # 검증, 권한 AOP
│   └── presentation/
│       ├── controller/      # 역할별 컨트롤러
│       └── dto/             # Request/Response DTO
├── internal/                # 서비스 간 Internal API
└── global/
    ├── feign/               # 외부 서비스 클라이언트
    ├── common/              # BaseEntity, Role
    └── infrastructure/      # Security, JWT, Redis, Swagger 설정
```

---

## 도메인 모델

```mermaid
erDiagram
    p_order {
        UUID id PK
        INT user_id
        UUID store_id
        VARCHAR order_number UK
        VARCHAR order_status
        TIMESTAMP pickup_time
        BOOLEAN need_disposables
        TEXT request
        INT estimated_time
        TEXT reason
        VARCHAR cancelled_by
        TIMESTAMP payment_completed_at
        TIMESTAMP accepted_at
        TIMESTAMP cooking_started_at
        TIMESTAMP cooking_completed_at
        TIMESTAMP picked_up_at
        TIMESTAMP cancelled_at
        TIMESTAMP created_at
        VARCHAR created_by
    }

    p_order_item {
        UUID id PK
        UUID order_id FK
        UUID menu_id
        VARCHAR menu_name
        DECIMAL menu_price
        INT quantity
        TIMESTAMP created_at
    }

    p_order_item_option {
        UUID id PK
        UUID order_item_id FK
        UUID menu_option_id
        VARCHAR option_name
        VARCHAR option_detail
        DECIMAL option_price
        TIMESTAMP created_at
    }

    p_order_outbox {
        UUID id PK
        VARCHAR aggregate_type
        UUID aggregate_id
        VARCHAR event_type
        TEXT payload
        TIMESTAMP created_at
    }

    p_order ||--o{ p_order_item : "contains"
    p_order_item ||--o{ p_order_item_option : "has"
    p_order ||--o{ p_order_outbox : "publishes"
```

---

## 주문 상태 흐름

```mermaid
stateDiagram-v2
    [*] --> PAYMENT_PENDING : 주문 생성

    PAYMENT_PENDING --> PENDING : 결제 성공 (PaymentSucceededEvent)
    PAYMENT_PENDING --> PAYMENT_FAILED : 결제 실패

    PENDING --> ACCEPTED : 점주 수락
    PENDING --> REJECT_PENDING : 점주 거절 요청
    PENDING --> CANCEL_PENDING : 고객/점주/시스템 취소 요청
    PENDING --> CANCEL_PENDING : 10분 타임아웃 (시스템 자동 취소)

    ACCEPTED --> COOKING : 셰프 조리 시작
    ACCEPTED --> CANCEL_PENDING : 점주 취소

    REJECT_PENDING --> REJECTED : 환불 완료
    REJECT_PENDING --> REFUND_ERROR : 환불 타임아웃 (30분)

    COOKING --> READY : 조리 완료
    COOKING --> CANCEL_PENDING : 점주 취소

    READY --> COMPLETED : 픽업 완료

    CANCEL_PENDING --> CANCELLED : 환불 완료 (PaymentRefundedEvent)
    CANCEL_PENDING --> REFUND_ERROR : 환불 타임아웃 (30분)

    PAYMENT_FAILED --> [*]
    REJECTED --> [*]
    COMPLETED --> [*]
    CANCELLED --> [*]
    REFUND_ERROR --> [*]
```

---

## 레이어 아키텍처

```mermaid
graph TD
    subgraph Presentation["Presentation Layer"]
        CC[CustomerOrderController]
        OC[OwnerOrderController]
        ChC[ChefOrderController]
        AC[AdminOrderController]
        IC[InternalOrderController]
    end

    subgraph Application["Application Layer"]
        OS[OrderServiceImpl]
    end

    subgraph Domain["Domain Layer"]
        OE[OrderEntity]
        OIE[OrderItemEntity]
        OIOe[OrderItemOptionEntity]
        OOE[OrderOutboxEntity]
        OR[OrderRepository]
    end

    subgraph Infrastructure["Infrastructure Layer"]
        TW[OrderWorkflowImpl<br/>Temporal]
        TA[OrderActivityImpl<br/>Temporal]
        KP[OrderEventProducer<br/>Kafka]
        KL[OrderEventListener<br/>Kafka]
        AOP[OrderAspect<br/>AOP]
        FC[FeignClients<br/>Store / Menu / Payment]
    end

    CC & OC & ChC & AC & IC --> OS
    OS --> OR
    OS --> TW
    OS --> KP
    TW --> TA
    TA --> OR
    KP --> OOE
    KL --> OS
    AOP -.->|Intercepts| OS
    FC -.->|Called by AOP| AOP
```

---

## 주문 생성 플로우

```mermaid
sequenceDiagram
    actor Customer
    participant API as CustomerOrderController
    participant AOP as OrderAspect
    participant SVC as OrderServiceImpl
    participant Temporal as OrderWorkflow
    participant Activity as OrderActivity
    participant DB as PostgreSQL
    participant Outbox as OrderOutboxEntity
    participant Kafka as Kafka
    participant Payment as Payment Service

    Customer->>API: POST /api/orders
    API->>AOP: @ValidateStoreAndMenu
    AOP->>AOP: Feign → StoreClient, MenuClient 검증
    AOP->>SVC: 검증 통과
    SVC->>SVC: 중복 주문 체크
    SVC->>Temporal: startWorkflow(OrderWorkflow)
    Temporal->>Activity: createOrderInDb()
    Activity->>DB: ORDER 저장 (PAYMENT_PENDING)
    Activity->>Outbox: OrderCreatedEvent 저장
    Outbox-->>Kafka: 이벤트 발행 (order.created)
    Kafka-->>Payment: OrderCreatedEvent 수신
    Payment-->>Kafka: PaymentSucceededEvent 발행
    Kafka-->>SVC: OrderEventListener 수신
    SVC->>Temporal: signalStatusChanged(PENDING)
    Temporal->>Activity: updateOrderStatusInDb(PENDING)
    Activity->>DB: 상태 업데이트
    Activity->>Outbox: OrderPendingEvent 저장
    Outbox-->>Kafka: 이벤트 발행 (order.pending)
    API-->>Customer: OrderResponseDto
```

---

## 주문 수락/거절/취소 플로우

```mermaid
sequenceDiagram
    actor Owner
    participant API as OwnerOrderController
    participant SVC as OrderServiceImpl
    participant Temporal as OrderWorkflow
    participant Activity as OrderActivity
    participant DB as PostgreSQL
    participant Kafka as Kafka
    participant Payment as Payment Service

    Note over Temporal: 결제 완료 후 10분 타임아웃 대기

    alt 수락
        Owner->>API: PATCH /api/orders/{id}/accept
        API->>SVC: acceptOrder(orderId, estimatedTime)
        SVC->>Temporal: signalStatusChanged(ACCEPTED)
        Temporal->>Activity: updateOrderStatusInDb(ACCEPTED)
        Activity->>DB: 상태 업데이트
        Activity->>Kafka: OrderAcceptedEvent 발행
    else 거절
        Owner->>API: PATCH /api/orders/{id}/reject
        API->>SVC: rejectOrder(orderId, reason)
        SVC->>Temporal: signalStatusChanged(REJECT_PENDING)
        Temporal->>Temporal: PaymentCancelWorkflow 시작
        Payment-->>Kafka: PaymentRefundedEvent
        Kafka-->>SVC: signalRefundCompleted()
        Temporal->>Activity: finalizeOrder(REJECTED)
        Activity->>DB: 상태 업데이트
    else 타임아웃 (10분)
        Temporal->>Temporal: 자동 취소 (SYSTEM)
        Temporal->>Temporal: PaymentCancelWorkflow 시작
    end
```

---

## 취소/환불 플로우

```mermaid
sequenceDiagram
    actor Actor as Customer / Owner / System
    participant SVC as OrderServiceImpl
    participant Temporal as OrderWorkflow
    participant Activity as OrderActivity
    participant DB as PostgreSQL
    participant Payment as Payment Service
    participant Kafka as Kafka

    Actor->>SVC: cancelOrder(orderId, reason, cancelledBy)
    SVC->>Temporal: signalStatusChanged(CANCEL_PENDING)
    Temporal->>Activity: updateOrderStatusInDb(CANCEL_PENDING)
    Activity->>DB: 상태 업데이트

    Temporal->>Temporal: PaymentCancelWorkflow 시작
    Payment-->>Kafka: PaymentRefundedEvent 발행

    alt 환불 성공 (30분 이내)
        Kafka-->>SVC: OrderEventListener 수신
        SVC->>Temporal: signalRefundCompleted()
        Temporal->>Activity: finalizeOrder(CANCELLED)
        Activity->>DB: 상태 업데이트
        Activity->>Kafka: OrderCancelledEvent 발행
    else 환불 타임아웃 (30분)
        Temporal->>Activity: handleRefundTimeout()
        Activity->>DB: 상태 → REFUND_ERROR
    end
```

---

## Temporal Workflow 구조

```mermaid
graph LR
    subgraph OrderWorkflow["OrderWorkflow (Temporal)"]
        direction TB
        S1[주문 생성<br/>createOrderInDb]
        S2[결제 승인<br/>PaymentApproveWorkflow]
        S3[점주 수락 대기<br/>10분 타임아웃]
        S4[조리 단계<br/>COOKING → READY]
        S5{취소/환불}
        S6[PaymentCancelWorkflow]

        S1 --> S2
        S2 --> S3
        S3 -->|수락| S4
        S3 -->|거절/타임아웃| S5
        S4 -->|취소| S5
        S5 --> S6
    end

    Signal["signalStatusChanged()"] -.->|Signal| S3
    Signal -.->|Signal| S4
    RefundSignal["signalRefundCompleted()"] -.->|Signal| S6
```

---

## AOP 검증 흐름

```mermaid
graph TD
    Request[HTTP 요청] --> AOP

    subgraph AOP["OrderAspect (AOP)"]
        VSM["@ValidateStoreAndMenu<br/>주문 생성 시"]
        SOR["@StoreOwnershipRequired<br/>점주 권한 필요 시"]
    end

    VSM --> SC[StoreClient<br/>가게 존재 확인]
    VSM --> MC[MenuClient<br/>메뉴/옵션 존재 확인]
    VSM --> CTX[OrderValidationContext<br/>ThreadLocal 저장]
    SOR --> SUC[StoreClient<br/>점주 소유권 확인]

    SC & MC --> R4J[Resilience4j<br/>Circuit Breaker / Retry]
    R4J --> FS[Feign 요청]
    CTX --> SVC[OrderService]
    SUC --> SVC
```

---

## 이벤트 토픽 구조

```mermaid
graph LR
    subgraph Publish["Order Service → Kafka"]
        E1[order.created<br/>OrderCreatedEvent]
        E2[order.pending<br/>OrderPendingEvent]
        E3[order.accepted<br/>OrderAcceptedEvent]
        E4[order.cancelled<br/>OrderCancelledEvent]
    end

    subgraph Subscribe["Kafka → Order Service"]
        E5[payment.succeeded<br/>PaymentSucceededEvent]
        E6[payment.refunded<br/>PaymentRefundedEvent]
    end

    OrderOutbox["OrderOutboxEntity<br/>(Outbox Pattern)"] --> E1 & E2 & E3 & E4
    E5 --> OrderEventListener
    E6 --> OrderEventListener
    OrderEventListener --> Temporal["Temporal Workflow<br/>signalStatusChanged()"]
```

---

## API 엔드포인트

### Customer (`CUSTOMER` 역할)

| Method | Path | 설명 |
|--------|------|------|
| POST | `/api/orders` | 주문 생성 |
| GET | `/api/orders/my` | 나의 주문 목록 (페이지네이션) |
| GET | `/api/orders/my/active` | 나의 활성 주문 |
| PATCH | `/api/orders/{orderId}/customer-cancel` | 주문 취소 |

### Owner (`OWNER` 역할)

| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/orders/my-store` | 가게 주문 목록 (페이지네이션) |
| GET | `/api/orders/my-store/active` | 가게 활성 주문 |
| PATCH | `/api/orders/{orderId}/accept` | 주문 수락 (예상 시간 포함) |
| PATCH | `/api/orders/{orderId}/reject` | 주문 거절 (이유 포함) |
| PATCH | `/api/orders/{orderId}/store-cancel` | 가게 측 취소 |

### Chef (`CHEF` 역할)

| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/orders/chef/today` | 오늘의 활성 주문 |
| PATCH | `/api/orders/{orderId}/start-cooking` | 조리 시작 |
| PATCH | `/api/orders/{orderId}/ready` | 조리 완료 (픽업 대기) |

### Admin (`MASTER` / `MANAGER` 역할)

| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/admin/orders` | 전체 주문 목록 (필터/페이지) |
| GET | `/api/admin/orders/stats` | 주문 통계 |

### Internal (서비스 간 통신)

| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/internal/orders/{orderId}` | 주문 상세 조회 |
| GET | `/api/internal/orders/{orderId}/exists` | 주문 존재 여부 확인 |

---

## 주요 설계 패턴

| 패턴 | 적용 위치 | 목적 |
|------|-----------|------|
| Temporal Workflow | `OrderWorkflowImpl` | 분산 트랜잭션 상태 머신 |
| Outbox Pattern | `OrderOutboxEntity` + `OrderEventProducer` | 이벤트 발행 신뢰성 보장 |
| Saga Pattern | Temporal Child Workflow | Payment 분산 트랜잭션 |
| Pessimistic Lock | `findByIdWithLock()` | 동시 상태 변경 방지 |
| AOP | `OrderAspect` | 검증/권한 횡단 관심사 분리 |
| Circuit Breaker | Resilience4j on Feign | 외부 서비스 장애 격리 |

---

## 실행 환경

- **Port**: 8082
- **Docker**: `eclipse-temurin:21-jre` 기반
- **외부 설정**: `/config/` 디렉터리의 `common.yml`, `kafka-topics.yml`, `spot-order.yml`
