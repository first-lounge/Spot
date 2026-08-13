<div align="center">
 <h1> Spot </h1>
 <p>픽업 주문 서비스를 위한 MSA 기반 백엔드 프로젝트</p>
</div>

## 프로젝트 소개

종로구 혜화동 근처에서 운영중인 음식점들의 픽업 주문 관리, 결제, 그리고 주문 내역 관리 기능을 제공하는 플랫폼입니다.

## 시작 가이드

### 요구사항

- Java 21 / Spring Boot 3.5.9 / Spring Cloud 2025.0.1
- PostgreSQL, Redis, Kafka, Temporal
- Kubernetes (EKS 1.35 / 로컬 k3d 1.30), Terraform, Helm, Kustomize, ArgoCD (GitOps)
- Prometheus, Grafana, Loki, fluent-bit
- k6 (부하 테스트)

### 팀 컨벤션

아래 명령어를 이용하여 convention을 지켜주세요

```bash
git config core.hooksPath .githooks
```

### 로컬 Docker Compose 실행

아래 명령어를 통해 쉽게 도커 컨테이너에서 사용할 수 있습니다.

```bash
./gradlew clean build -x test
docker-compose up --build -d
```

PostgreSQL, Redis, Kafka(KRaft 3-broker), Kafka Connect, Temporal 및 전체 서비스가 함께 기동됩니다.

### 로컬 k3d 실행

`docker`, `k3d`, `kubectl`, `helm` 이 설치돼 있어야 합니다.

#### 1. 시크릿 파일 생성

`k8s/base/secret/.env` 를 만들고 아래 6개 키에 값을 채웁니다 (gitignore 대상).

```ini
# [PostgreSQL]
SPRING_DATASOURCE_USERNAME=
SPRING_DATASOURCE_PASSWORD=

# [JWT]
SPRING_JWT_SECRET=

# [EMAIL]
EMAIL_USERNAME=
EMAIL_PASSWORD=

# [TOSS]
TOSS_SECRET_KEY=
```

> DB 주소·Kafka 주소·Feign URL 등 나머지 설정값은 [`k8s/overlays/local/config/env-config/configs.env`](./k8s/overlays/local/config/env-config/configs.env)에 이미 커밋돼 있으므로 따로 작성할 필요가 없습니다.

#### 2. 실행

> ⚠️ 로컬은 셸 스크립트 실행으로 ArgoCD는 사용하지 않습니다. (Dev/Prod는 GitOps)

```bash
# 전체 실행
./run_k3d.sh

# 부분 실행 예시
./run_k3d.sh --cluster
```

**⚙️ 부분 실행 옵션**

| 옵션                                  | 동작                                                                    |
| ------------------------------------- | ----------------------------------------------------------------------- |
| _(없음)_                              | 전체 실행                                                               |
| `--no-monitoring`                     | 모니터링 스택을 제외하고 전체 실행                                      |
| `--cluster`                           | k3d 클러스터만 재생성 — 레지스트리도 함께 삭제되므로 이미지 재빌드 필요 |
| `--build`                             | 서비스 이미지 빌드·push만 실행                                          |
| `--bootstrap`                         | 네임스페이스·ConfigMap·Secret 생성 + ingress-nginx 설치                 |
| `--infra` / `--monitoring` / `--spot` | 해당 네임스페이스만 재배포                                              |

#### 3. hosts 파일 등록

> ⚠️ 배포된 서비스는 Ingress 도메인으로 접근하기 때문에 hosts 파일 등록이 필수입니다.

- **Windows**

  ```
  # 1. 메모장을 "관리자 권한으로 실행"한 뒤, 아래 파일을 엽니다
  C:\Windows\System32\drivers\etc\hosts

  # 2. 파일 맨 아래에 아래 내용을 추가하고 저장합니다
  127.0.0.1 www.spot kafka.spot temporal.spot grafana.spot
  ```

- **macOS·Linux**

  ```bash
  # 1. 터미널에서 hosts 파일을 엽니다
  sudo vi /etc/hosts

  # 2. 파일 맨 아래에 아래 내용을 추가하고 저장합니다
  127.0.0.1 www.spot kafka.spot temporal.spot grafana.spot
  ```

- **서비스별 주소**

  | 서비스      | 주소                 |
  | ----------- | -------------------- |
  | Gateway API | http://www.spot      |
  | Kafka UI    | http://kafka.spot    |
  | Temporal UI | http://temporal.spot |
  | Grafana     | http://grafana.spot  |

  > 더미 데이터와 함께 실행하려면 [data/README.md](./data/README.md)를 참고하세요.

## Project Structure

| 디렉터리                                                                                                                                                            | 설명                                                                                                                               |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `spot-gateway`                                                                                                                                                      | Spring Cloud Gateway (라우팅, 인증/인가)                                                                                           |
| [`spot-user`](./spot-user/README.md) / [`spot-store`](./spot-store/README.md) / [`spot-order`](./spot-order/README.md) / [`spot-payment`](./spot-payment/README.md) | 도메인 서비스 (**링크 = 각 도메인별 README**)                                                                                      |
| `spot-mono`                                                                                                                                                         | 모놀리식 통합 모듈                                                                                                                 |
| `FE`                                                                                                                                                                | 프론트엔드                                                                                                                         |
| `config`                                                                                                                                                            | 공통 Spring 설정(yml) — Docker Compose 실행 시 사용 (`./config:/config` 마운트)                                                    |
| `k8s`                                                                                                                                                               | Kustomize(base/overlays) + Helm 차트(spot-apps), ArgoCD App-of-Apps(`argo/` — Dev/Prod GitOps 전용), k3d 부트스트랩, 배포 스크립트 |
| `k8s/base/secret`                                                                                                                                                   | `.env` → Secret 생성 (kustomize secretGenerator, `.env`는 gitignore 대상)                                                          |
| `k8s/overlays/local` · `k8s/overlays/dev`                                                                                                                           | 환경별 매니페스트 (config / infra / monitoring)                                                                                    |
| `terraform`                                                                                                                                                         | AWS 인프라 IaC (modules + environments) — [실행 가이드](./terraform/README.md)                                                     |
| `k6`                                                                                                                                                                | 부하 테스트 스크립트                                                                                                               |
| `docs`                                                                                                                                                              | 기능 문서                                                                                                                          |

## Application Flow

![](./docs/application/image/spot-application.png)

### 서비스 구성

| 서비스          | 포트 | 역할                         |
| --------------- | ---- | ---------------------------- |
| API Gateway     | 8080 | 라우팅, 인증/인가            |
| User Service    | 8081 | 회원 가입, 로그인, 정보 수정 |
| Order Service   | 8082 | 주문 생성, 주문 조회         |
| Store Service   | 8083 | 매장 및 메뉴 조회            |
| Payment Service | 8084 | 결제 처리, PG 연동           |

### 주요 흐름

1. **회원 관리**: API Gateway → User Service → User DB
2. **매장/메뉴 조회**: API Gateway → Store Service → Store/Menu DB (Redis 캐싱)
3. **주문 생성**: API Gateway → Order Service → 사용자/가게/메뉴 유효성 검증 → Order DB
4. **결제 처리**: Order Service → Payment Service → TossPG 승인/취소 API 호출
5. **결제 결과**: TossPG Webhook → Payment Service → Kafka → 결제 결과 확정

### 서비스 간 통신

- **동기 통신**: OpenFeign을 통한 REST API 호출 (Resilience4j 서킷 브레이커 적용)
- **비동기 통신**: Kafka를 통한 이벤트 기반 메시징
- **워크플로 오케스트레이션**: Temporal을 통한 주문/결제 워크플로 관리
- **캐싱**: Redis(ElastiCache)를 통한 메뉴/매장 정보 캐싱

## Infrastructure

AWS Dev 환경 기준입니다. Terraform으로 프로비저닝하며 EKS 위에서 운영됩니다. (Prod 환경은 추후 구성 예정)

![](./docs/infra/image/3차-Dev.png)

### 네트워크 구성

- **Region**: ap-northeast-2 (서울)
- **VPC**: 10.0.0.0/16, 2개의 Availability Zone (AZ-a, AZ-c)
- **Public Subnet**: NAT Instance, ALB
- **Private Subnet**: EKS, RDS, ElastiCache

### 트래픽 흐름

```
User → Route 53 → ALB (AWS Load Balancer Controller) → Spring Cloud Gateway → 각 서비스
```

### 컴퓨팅

- **EKS**
  - 5개 서비스 (Gateway, User, Store, Order, Payment) 및 인프라 워크로드(Kafka, Temporal, 모니터링) 배포
  - SPOT 노드 사용
- **AWS Load Balancer Controller**: Ingress 기반 ALB 자동 생성 및 트래픽 분산
- **ECR**: 컨테이너 이미지 저장소

### 배포 (GitOps)

- **ArgoCD**
  - App-of-Apps 패턴으로 `k8s/`의 매니페스트를 pull 방식으로 동기화
  - Terraform(`environments/argo`)으로 부트스트랩
- **GitHub Actions**: dev 머지 시 변경된 서비스만 빌드해 ECR push (OIDC 인증) — 클러스터 반영은 ArgoCD 담당
- **External Secrets Operator**: Parameter Store의 값을 클러스터 Secret으로 동기화 (`ClusterSecretStore` + `ExternalSecret`)
- **external-dns**: Ingress 생성 시 Route 53 레코드 자동 등록

> GitOps는 Dev/Prod 환경에만 적용됩니다. 로컬 k3d는 셸 스크립트(`run_k3d.sh`)로 배포합니다.

### 데이터베이스 및 메시징

- **RDS**: PostgreSQL 16 — Dev는 단일 인스턴스에 서비스별 데이터베이스, Prod는 서비스별 인스턴스 분리 예정
- **ElastiCache**: Redis 7 캐시
- **Kafka**: Strimzi Operator (KRaft 모드)
- **Temporal**: 워크플로 엔진

### 보안 및 관리

| 서비스          | 용도                                                                         |
| --------------- | ---------------------------------------------------------------------------- |
| IAM             | 접근 권한 관리 (GitHub Actions OIDC 포함)                                    |
| WAF             | 웹 방화벽 (rate limiting)                                                    |
| Secrets Manager | RDS 마스터 암호 관리                                                         |
| Parameter Store | 앱 시크릿 저장 — External Secrets Operator(ESO)가 클러스터 Secret으로 동기화 |
| KMS             | tfstate 암호화 (S3 backend, 전 환경 공용 키)                                 |
| ACM             | TLS 인증서 관리                                                              |

### 모니터링 및 로깅

- **Prometheus / Grafana**: 메트릭 수집 및 대시보드 (서비스·Kafka·Temporal 모니터링)
- **Loki / fluent-bit**: 로그 수집 및 조회
- **CloudWatch / CloudTrail**: AWS 리소스 모니터링 및 감사 로그
- **S3**: 정적 파일, ALB 액세스 로그 및 백업 스토리지

### Terraform 폴더 구조

```
terraform/
├── environments/
│   ├── bootstrap/   # tfstate용 S3 + DynamoDB lock (최초 1회, destroy 금지)
│   ├── dev/         # Dev 환경 (VPC, EKS, RDS 등)
│   └── argo/        # ArgoCD 루트 모듈 (dev 클러스터를 참조, 별도 state)
└── modules
    ├─acm
    ├─argocd
    ├─ecr
    ├─eks
    ├─github-oidc
    ├─network
    ├─rds
    ├─redis
    ├─route53
    ├─s3
    ├─security
    └─waf
```

> 루트 모듈별 역할과 실행(apply/destroy) 순서, ArgoCD 접속 방법은 [terraform/README.md](./terraform/README.md)를 참고하세요.
