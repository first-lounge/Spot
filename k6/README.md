# Spot k6 Load Testing Suite

Spot MSA 서비스를 위한 체계적인 부하 테스트 프레임워크

## 폴더 구조

```
k6/
├── config.yaml               # 서버 IP, 테스트 데이터 설정
├── .env                      # 민감한 정보 (비밀번호 등)
├── .env.example              # .env 템플릿
│
├── config/                   # JS 설정 파일
│   ├── index.js              # 설정 통합 모듈
│   ├── endpoints.js          # API 엔드포인트 정의
│   └── thresholds.js         # 성능 임계값 설정
│
├── lib/                      # 공통 라이브러리
│   ├── auth.js               # 인증 헬퍼 함수
│   └── helpers.js            # 유틸리티 함수
│
├── scenarios/                # 서비스별 테스트 시나리오
│   ├── user/                 # spot-user (8081)
│   ├── store/                # spot-store (8083)
│   ├── order/                # spot-order (8082)
│   └── payment/              # spot-payment (8084)
│
├── tests/                    # 테스트 실행 스크립트
│   ├── smoke.js              # 스모크 테스트
│   ├── load.js               # 부하 테스트
│   ├── stress.js             # 스트레스 테스트
│   ├── spike.js              # 스파이크 테스트
│   └── order-only.js         # 주문생성 테스트
│
├── logs/                     # 테스트 결과 로그
└── run.sh                    # 실행 스크립트
```

## 빠른 시작

### 1. 환경 설정

```bash
cd k6

# .env 파일 생성 (민감한 정보)
cp .env.example .env
vi .env  # 비밀번호 등 수정

# config.yaml 수정 (서버 IP, 테스트 데이터)
vi config.yaml
```

### 2. 설정 파일

#### `config.yaml` - 서버 및 테스트 데이터

```yaml
server:
  base_url: 'http://139.150.11.41:8080'

test_data:
  store_id: 'your-store-uuid'
  menu_id: 'your-menu-uuid'
```

#### `.env` - 민감한 정보 (Git 제외)

```bash
CUSTOMER_USERNAME=customer
CUSTOMER_PASSWORD=your_password

OWNER_USERNAME=owner
OWNER_PASSWORD=your_password
```

### 3. 테스트 실행

```bash
# 스모크 테스트 (빠른 검증)
./run.sh smoke

# 부하 테스트 (일반 부하)
./run.sh load

# 스트레스 테스트 (한계 테스트)
./run.sh stress

# 스파이크 테스트 (급격한 부하)
./run.sh spike
```

### 4. 명령줄에서 설정 오버라이드

```bash
# 서버 URL 변경
./run.sh smoke -e BASE_URL=http://localhost:8080

# 테스트 데이터 변경
./run.sh smoke -e STORE_ID=abc123 -e MENU_ID=xyz789
```

## 테스트 유형

| 테스트 | 목적               | VUs   | 시간 |
| ------ | ------------------ | ----- | ---- |
| smoke  | 기본 동작 검증     | 1     | 30초 |
| load   | 일반 부하 성능     | 10    | 5분  |
| stress | 한계점 파악        | 100   | 13분 |
| spike  | 급격한 트래픽 대응 | 5→100 | 3분  |

## 설정 우선순위

1. **명령줄 옵션** (`-e BASE_URL=...`) - 최우선
2. **`.env` 파일** - 민감한 정보
3. **`config.yaml`** - 서버 IP, 테스트 데이터
4. **기본값** - 코드 내 하드코딩 값

## 결과 확인

테스트 완료 후 `logs/` 폴더에 결과 파일 생성:

```
logs/
├── 20260129_223000_smoke_result.json    # 상세 메트릭
└── 20260129_223000_smoke_summary.json   # 요약 통계
```

## 서비스별 API 커버리지

### spot-user (8081)

- 로그인, 회원가입, 토큰 갱신
- 사용자 조회/수정/삭제
- 관리자: 사용자 목록, 통계

### spot-store (8083)

- 매장 CRUD, 검색
- 메뉴/옵션 CRUD
- 카테고리 관리
- 리뷰 관리

### spot-order (8082)

- 고객: 주문 생성/조회/취소
- 점주: 주문 수락/거절/완료
- 셰프: 조리 시작/완료

### spot-payment (8084)

- 결제 확인/취소
- 결제 내역 조회
- 빌링키 관리

## 주의사항

- `.env` 파일은 절대 Git에 커밋하지 마세요
- 프로덕션 환경에서는 stress/spike 테스트 주의
- 테스트 데이터 생성 시나리오는 기본적으로 비활성화됨
