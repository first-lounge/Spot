# Spot Frontend

Spot 픽업 주문 서비스의 프론트엔드입니다. Next.js App Router 기반 SPA로, API 게이트웨이(spot-gateway)를 통해 백엔드 마이크로서비스와 통신합니다.

## 기술 스택

- **Next.js 16** (App Router, Turbopack)
- **React 19** + TypeScript
- **Tailwind CSS 4**
- **Zustand** — 인증/장바구니 상태 관리 (localStorage persist)
- **Axios** — API 클라이언트 (토큰 자동 첨부, 401 시 refresh 재시도 인터셉터)
- **@tosspayments/payment-sdk** — 토스페이먼츠 빌링키 결제

## 로컬 실행

### 1. 백엔드 기동

레포 루트에서 전체 백엔드(게이트웨이 + 4개 서비스 + 인프라)를 띄웁니다. 게이트웨이가 `localhost:8080`에 노출됩니다.

```bash
# 레포 루트에서
docker-compose up -d
```

### 2. 환경변수 설정

`FE/spot/.env.local` 파일을 생성합니다 (gitignore 대상이라 직접 만들어야 함):

```bash
NEXT_PUBLIC_TOSS_CLIENT_KEY=test_ck_...   # 토스페이먼츠 테스트 클라이언트 키
```

> 시크릿 키(`test_sk_...`)는 백엔드용으로 레포 루트 `.env`의 `TOSS_SECRET_KEY`에 설정합니다. 클라이언트 키가 없으면 빌링키 미보유 사용자의 카드 결제가 동작하지 않습니다.

### 3. 개발 서버 실행

```bash
cd FE/spot
npm install
npm run dev    # http://localhost:3000
```

## 환경변수

| 변수 | 용도 | 기본값 |
|---|---|---|
| `NEXT_PUBLIC_TOSS_CLIENT_KEY` | 토스페이먼츠 클라이언트 키 (브라우저 노출) | 없음 (필수) |
| `API_URL` | API 게이트웨이 주소 (Next.js rewrite 프록시 대상) | `http://localhost:8080` |

`/api/*` 요청은 Next.js rewrite를 통해 `${API_URL}/api/*`로 프록시됩니다 (CORS 우회). 배포 환경에서는 `API_URL`에 게이트웨이 주소를 주입하면 됩니다.

## 디렉토리 구조

```
app/                # 라우트 (App Router)
  admin/            # 관리자 대시보드 (MANAGER/MASTER)
  cart/             # 장바구니 + 주문/결제
  join/, login/     # 회원가입, 로그인
  mypage/           # 마이페이지 (가게 관리, 빌링키, 셰프)
  orders/           # 주문 내역
  payemnts/         # 결제 성공/실패 콜백 (폴더명 오타 — failUrl과 일치하므로 변경 시 함께 수정)
  search/, stores/  # 가게 검색, 가게 상세
components/         # UI 컴포넌트 (Button, Input, 주문관리, 매출 대시보드 등)
lib/                # API 모듈 (api.ts 공용 클라이언트 + 도메인별 모듈)
store/              # Zustand 스토어 (authStore, cartStore)
types/              # 백엔드 응답 DTO와 일치하는 타입 정의
```

## 백엔드 연동 시 주의사항

타입(`types/index.ts`)과 API 모듈은 백엔드 DTO 필드명과 **정확히 일치**해야 합니다. 과거 불일치로 인한 런타임 버그가 있었고 아래와 같이 정리됐습니다:

- **메뉴 옵션** (spot-store): 요청·응답 모두 `name` / `detail` / `price` 사용 (~~optionName/optionDetail/optionPrice~~ 아님)
- **주문 항목 옵션** (spot-order 응답): `orderItems[].options` 배열, 각 옵션은 `optionName` / `optionDetail` / `optionPrice`
- **주문 생성 요청** (spot-order): 옵션은 `options: [{ menuOptionId }]` 형태

## 빌드

```bash
npm run build
```

`next.config.ts`의 `turbopack.root`는 프로젝트 디렉토리로 고정되어 있습니다. 상위 경로에 한글(비ASCII)이 포함되면 Turbopack이 워크스페이스 루트를 잘못 추론해 패닉으로 빌드가 실패하기 때문에 제거하면 안 됩니다.

## 알려진 이슈 (백엔드 미구현 — 추후 처리 예정)

| 기능 | FE 호출 경로 | 상태 |
|---|---|---|
| 셰프 페이지 (`/mypage/chef`) | `/api/chefs/**` | 게이트웨이 라우트·백엔드 모두 없음. 페이지 진입 시 에러 |
| 매출 대시보드 (가게 관리 탭) | `/api/stores/{id}/sales/**` | 백엔드 미구현. 데이터는 spot-order에 있어 라우팅 설계 필요 |
| 관리자 주문 상태 변경 | `PATCH /api/orders/{id}/status` | 백엔드에 없음. 기존 전이 엔드포인트(accept/reject 등)로 FE 변경 시 해결 가능 |
| 로그아웃 서버 무효화 | `POST /api/auth/logout` | 엔드포인트는 spot-user에 존재하나 게이트웨이 `user-auth` 라우트에 누락 (쿠키 삭제는 정상 동작) |
