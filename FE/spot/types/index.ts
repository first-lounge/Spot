// API Response 공통 타입
export interface ApiResponse<T> {
  isSuccess: boolean;
  code: string;
  message: string;
  result: T;
}

// 페이지네이션 응답 타입
export interface PageResponse<T> {
  content: T[];
  totalPages: number;
  totalElements: number;
  size: number;
  number: number;
}

// 사용자 관련 타입
export type Role = 'CUSTOMER' | 'OWNER' | 'CHEF' | 'MANAGER' | 'MASTER';

/**
 * 로그인한 사용자.
 * id·username·role 은 토큰만으로도 알 수 있지만, 나머지 프로필은 서버에서 받아와야 안다.
 * 받아오기 전(또는 실패)에는 "모름" = null/undefined 로 둔다. 가짜 값(나이 0, 성별 남성)으로 채우지 않는다.
 * 백엔드 UserResponseDTO 도 age(Integer)·male(Boolean)은 null 가능.
 */
export interface User {
  id: number;
  username: string;
  role: Role;
  nickname?: string | null;
  email?: string | null;
  roadAddress?: string | null;
  addressDetail?: string | null;
  age?: number | null;
  male?: boolean | null;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  accessToken: string;
  refreshToken: string;
}

export interface JoinRequest {
  username: string;
  password: string;
  nickname: string;
  email: string;
  male: boolean;
  age: number;
  roadAddress: string;
  addressDetail: string;
  role: Role;
}

// 가게 관련 타입
export type StoreStatus = 'PENDING' | 'APPROVED' | 'REJECTED';

export interface Store {
  id: string;
  name: string;
  description?: string;
  roadAddress: string;
  addressDetail: string;
  phoneNumber: string;
  openTime: string;
  closeTime: string;
  categoryNames?: string[];
  status?: StoreStatus;
  isDeleted?: boolean;
  categories?: Category[];
  menus?: Menu[];
}

// 가게 등록 요청 (POST /api/stores)
export interface StoreCreateRequest {
  name: string;
  phoneNumber: string;
  roadAddress: string;
  addressDetail: string;
  openTime: string;
  closeTime: string;
  categoryNames: string[];
  ownerId: number;
  chefId: number;
}

// 가게 수정 요청 (PATCH /api/stores/{id}) — 백엔드 StoreUpdateRequest 와 동일 필드
export interface StoreUpdateRequest {
  name?: string;
  roadAddress?: string;
  addressDetail?: string;
  phoneNumber?: string;
  openTime?: string;
  closeTime?: string;
  categoryNames?: string[];
}

export interface StoreListResponse {
  content: Store[];
  totalPages: number;
  totalElements: number;
  size: number;
  number: number;
}

// 카테고리 관련 타입
export interface Category {
  id: string;
  name: string;
}

// 메뉴 관련 타입
export interface Menu {
  id: string;
  storeId: string;
  name: string;
  category: string;
  price: number;
  description: string;
  imageUrl: string;
  isAvailable?: boolean;
  isHidden?: boolean;
  options?: MenuOption[];
}

export interface MenuOption {
  id: string;
  name: string;
  price: number;
}

// 주문 관련 타입 — 백엔드 spot-order `OrderStatus` enum 과 1:1
export type OrderStatus =
  | 'PAYMENT_PENDING'
  | 'PAYMENT_FAILED'
  | 'PENDING'
  | 'ACCEPTED'
  | 'REJECT_PENDING'
  | 'REJECTED'
  | 'COOKING'
  | 'READY'
  | 'COMPLETED'
  | 'CANCEL_PENDING'
  | 'CANCELLED'
  | 'REFUND_ERROR';

export interface OrderItem {
  menuId: string;
  quantity: number;
  orderItemOptions?: OrderItemOption[];
}

export interface OrderItemOption {
  optionId: string;
  value: string;
}

export interface OrderCreateRequest {
  storeId: string;
  orderItems: OrderItem[];
  pickupTime: string;
  needDisposables: boolean;
  request?: string;
}

/**
 * FE 표준 주문 형태.
 * 백엔드는 두 가지 모양을 준다:
 *  - spot-order `OrderResponseDto`: `id` / `orderStatus`
 *  - spot-user  `OrderResponse`(관리자 대시보드): `orderId` / `status`
 * lib/orders.ts 의 normalizeOrder() 가 둘 다 이 형태로 맞춘다. 화면에서는 이 타입만 쓴다.
 */
export interface OrderResponse {
  orderId: string;
  userId: number;
  storeId: string;
  storeName: string;
  orderNumber: string;
  needDisposables: boolean;
  request: string;
  pickupTime: string;
  status: OrderStatus;
  estimatedTime?: number;
  reason?: string;
  cancelledBy?: string;
  createdAt: string;
  orderItems: OrderItemResponse[];
  totalAmount: number;
}

/** 백엔드가 실제로 내려주는 주문 응답(두 DTO의 합집합). normalizeOrder() 입력용. */
export interface RawOrderResponse extends Partial<Omit<OrderResponse, 'orderId' | 'status' | 'totalAmount'>> {
  id?: string;
  orderId?: string;
  orderStatus?: OrderStatus;
  status?: OrderStatus;
  totalAmount?: number | string | null;
}

export interface OrderItemResponse {
  id: string;
  menuId: string;
  menuName: string;
  menuPrice: number;
  quantity: number;
  optionsTotal: number;
  subtotal: number;
  options?: OrderItemOptionResponse[];
}

export interface OrderItemOptionResponse {
  id: string;
  menuOptionId: string;
  optionName: string;
  optionDetail?: string;
  optionPrice: number;
}

// 결제 관련 타입
export type PaymentMethod = 'CREDIT_CARD' | 'DEBIT_CARD' | 'BANK_TRANSFER';

export interface PaymentConfirmRequest {
  title: string;
  content: string;
  userId: number;
  orderId: string;
  paymentMethod: PaymentMethod;
  paymentAmount: number;
}

export interface PaymentConfirmResponse {
  paymentId: string;
  status: string;
  amount: number;
  approvedAt: string;
}

// 장바구니 타입
export interface CartItem {
  menu: Menu;
  quantity: number;
  selectedOptions: MenuOption[];
}

export interface Cart {
  storeId: string;
  storeName: string;
  items: CartItem[];
  /** 담은 사용자. null/undefined = 비로그인 상태에서 담음 (로그인 시 그 사용자 것으로 귀속) */
  userId?: number | null;
}
