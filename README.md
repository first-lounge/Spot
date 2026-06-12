<div align="center">
 <h1> Spot </h1>
 <p>픽업 주문 서비스를 위한 MSA 기반 백엔드 프로젝트</p>
</div>

# Version
- Java 21 / Spring Boot 3.5.9 / Spring Cloud 2025.0.1
- PostgreSQL, Redis, Kafka, Temporal
- Kubernetes 1.35 (EKS / k3d), Terraform, Helm, Kustomize
- Prometheus, Grafana, Loki, fluent-bit
- k6 (부하 테스트)

# Getting Started

아래 명령어를 이용하여 convention을 지켜주세요
```bash
git config core.hooksPath .githooks
```

## 로컬 실행 (Docker Compose)
아래 명령어를 통해 쉽게 도커 컨테이너에서 사용할 수 있습니다.
```bash
./gradlew clean build -x test
docker-compose up --build -d
```
PostgreSQL, Redis, Kafka(KRaft 3-broker), Kafka Connect, Temporal 및 전체 서비스가 함께 기동됩니다.

## 로컬 Kubernetes (k3d)
```bash
./run_k3d.sh                  # k3d 클러스터 생성 및 배포
./k8s/deploy/deploy-local.sh  # 로컬 배포
```

# Project Structure
| 디렉터리 | 설명 |
|----------|------|
| `spot-gateway` | Spring Cloud Gateway (라우팅, 인증/인가) |
| `spot-user` / `spot-store` / `spot-order` / `spot-payment` | 도메인 서비스 |
| `spot-mono` | 모놀리식 통합 모듈 |
| `FE` | 프론트엔드 |
| `k8s` | Kustomize(base/overlays) + Helm 차트(spot-apps), k3d 부트스트랩, 배포 스크립트 |
| `terraform` | AWS 인프라 IaC (modules + environments) |
| `k6` | 부하 테스트 스크립트 |
| `docs` | 아키텍처/기능/트러블슈팅 문서 |

# Application Flow

![](./docs/application/image/spot-application.png)

### 서비스 구성
| 서비스 | 포트 | 역할 |
|--------|------|------|
| API Gateway | 8080 | 라우팅, 인증/인가 |
| User Service | 8081 | 회원 가입, 로그인, 정보 수정 |
| Order Service | 8082 | 주문 생성, 주문 조회 |
| Store Service | 8083 | 매장 및 메뉴 조회 |
| Payment Service | 8084 | 결제 처리, PG 연동 |

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

# Infrastructure
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
- **EKS**: 4개 서비스 (User, Store, Order, Payment) 배포, SPOT 노드 사용
- **AWS Load Balancer Controller**: Ingress 기반 ALB 자동 생성 및 트래픽 분산
- **ECR**: 컨테이너 이미지 저장소

### 데이터베이스 및 메시징
- **RDS**: PostgreSQL 16, 서비스별 독립 데이터베이스 (User, Store, Order, Payment)
- **ElastiCache**: Redis 7 캐시
- **Kafka**: Strimzi Operator (KRaft 모드)
- **Temporal**: 워크플로 엔진

### 보안 및 관리
| 서비스 | 용도 |
|--------|------|
| IAM | 접근 권한 관리 |
| WAF | 웹 방화벽 (rate limiting, ALB 연동) |
| Secrets Manager | 비밀 정보 관리 |
| Parameter Store | 설정 값 관리 |
| ACM | TLS 인증서 관리 |

### 모니터링 및 로깅
- **Prometheus / Grafana**: 메트릭 수집 및 대시보드 (서비스·Kafka·Temporal 모니터링)
- **Loki / fluent-bit**: 로그 수집 및 조회
- **CloudWatch / CloudTrail**: AWS 리소스 모니터링 및 감사 로그
- **S3**: 정적 파일, ALB 액세스 로그 및 백업 스토리지

### Terraform 구조
```
terraform/
├── environments/
│   ├── bootstrap/   # tfstate용 S3 + DynamoDB lock (최초 1회)
│   └── dev/         # Dev 환경
└── modules/
    ├── network/ security/ eks/ rds/ redis/
    └── s3/ ecr/ acm/ route53/ waf/ monitoring/
```
