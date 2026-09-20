import api from './api';
import type {
  ApiResponse,
  OrderCreateRequest,
  OrderResponse,
  OrderStatus,
  PageResponse,
  RawOrderResponse,
} from '@/types';

/**
 * 백엔드 주문 응답을 FE 표준 형태(OrderResponse)로 맞춘다.
 * - spot-order 는 `id` / `orderStatus`, spot-user(관리자 대시보드)는 `orderId` / `status` 로 내려준다.
 * - `totalAmount` 는 BigDecimal 이라 문자열로 올 수 있어 숫자로 바꾼다.
 */
export const normalizeOrder = (raw: RawOrderResponse): OrderResponse => ({
  ...(raw as Omit<OrderResponse, 'orderId' | 'status' | 'totalAmount'>),
  orderId: raw.orderId ?? raw.id ?? '',
  status: (raw.status ?? raw.orderStatus) as OrderStatus,
  orderItems: raw.orderItems ?? [],
  totalAmount: Number(raw.totalAmount ?? 0),
});

export const normalizeOrderPage = (
  page: PageResponse<RawOrderResponse>
): PageResponse<OrderResponse> => ({
  ...page,
  content: (page.content ?? []).map(normalizeOrder),
});

export const orderApi = {
  // 주문 생성
  createOrder: async (data: OrderCreateRequest): Promise<OrderResponse> => {
    const response = await api.post<ApiResponse<RawOrderResponse>>('/api/orders', data);
    return normalizeOrder(response.data.result);
  },

  // 내 주문 목록 조회
  getMyOrders: async (page = 0, size = 20): Promise<PageResponse<OrderResponse>> => {
    const response = await api.get<ApiResponse<PageResponse<RawOrderResponse>>>('/api/orders/my', {
      params: { page, size },
    });
    return normalizeOrderPage(response.data.result);
  },

  // 진행 중인 주문 조회
  getActiveOrders: async (): Promise<OrderResponse[]> => {
    const response = await api.get<ApiResponse<RawOrderResponse[]>>('/api/orders/my/active');
    return (response.data.result ?? []).map(normalizeOrder);
  },

  // 주문 취소
  cancelOrder: async (orderId: string, reason: string): Promise<OrderResponse> => {
    const response = await api.patch<ApiResponse<RawOrderResponse>>(
      `/api/orders/${orderId}/customer-cancel`,
      { reason }
    );
    return normalizeOrder(response.data.result);
  },
};

// OWNER용 주문 관리 API
export const ownerOrderApi = {
  // 내 가게 주문 목록 조회 (페이징)
  getMyStoreOrders: async (
    customerId?: number,
    date?: string,
    status?: string,
    page: number = 0,
    size: number = 20
  ): Promise<PageResponse<OrderResponse>> => {
    const params: Record<string, string | number> = { page, size };
    if (customerId) params.customerId = customerId;
    if (date) params.date = date;
    if (status) params.status = status;

    const response = await api.get<ApiResponse<PageResponse<RawOrderResponse>>>(
      '/api/orders/my-store',
      { params }
    );
    return normalizeOrderPage(response.data.result);
  },

  // 내 가게 활성 주문 조회
  getMyStoreActiveOrders: async (): Promise<OrderResponse[]> => {
    const response = await api.get<ApiResponse<RawOrderResponse[]>>(
      '/api/orders/my-store/active'
    );
    return (response.data.result ?? []).map(normalizeOrder);
  },

  // 주문 수락
  acceptOrder: async (
    orderId: string,
    estimatedTime: number
  ): Promise<OrderResponse> => {
    const response = await api.patch<ApiResponse<RawOrderResponse>>(
      `/api/orders/${orderId}/accept`,
      { estimatedTime }
    );
    return normalizeOrder(response.data.result);
  },

  // 주문 거절
  rejectOrder: async (orderId: string, reason: string): Promise<OrderResponse> => {
    const response = await api.patch<ApiResponse<RawOrderResponse>>(
      `/api/orders/${orderId}/reject`,
      { reason }
    );
    return normalizeOrder(response.data.result);
  },

  // 주문 취소 (가게 측)
  storeCancelOrder: async (orderId: string, reason: string): Promise<OrderResponse> => {
    const response = await api.patch<ApiResponse<RawOrderResponse>>(
      `/api/orders/${orderId}/store-cancel`,
      { reason }
    );
    return normalizeOrder(response.data.result);
  },

  // 주문 완료
  completeOrder: async (orderId: string): Promise<OrderResponse> => {
    const response = await api.patch<ApiResponse<RawOrderResponse>>(
      `/api/orders/${orderId}/complete`
    );
    return normalizeOrder(response.data.result);
  },
};

export default orderApi;
