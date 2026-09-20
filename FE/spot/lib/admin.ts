import {api} from './api';
import {normalizeOrder, normalizeOrderPage} from './orders';
import type {
  ApiResponse,
  OrderResponse,
  PageResponse,
  RawOrderResponse,
  Store,
  StoreUpdateRequest,
  User,
} from '@/types';

// 관리자용 통계 타입 — 백엔드 spot-user `AdminStatsResponseDto` 와 1:1
export interface AdminStats {
  totalUsers: number;
  totalOrders: number;
  totalStores: number;
  totalRevenue: number;
  recentOrders: OrderResponse[];
  userGrowth: Array<{ date: string; count: number }>;
  orderStats: Array<{ status: string; count: number }>;
}

// 사용자 관리 API (spot-user /api/admin/users)
export const adminUserApi = {
  // 전체 사용자 조회 (페이징)
  getAllUsers: async (page = 0, size = 20): Promise<PageResponse<User>> => {
    const response = await api.get<ApiResponse<PageResponse<User>>>(
      `/api/admin/users?page=${page}&size=${size}`
    );
    return response.data.result;
  },

  // 특정 사용자 조회
  getUser: async (userId: number): Promise<User> => {
    const response = await api.get<User>(`/api/users/${userId}`);
    return response.data;
  },

  // 사용자 역할 변경
  updateUserRole: async (userId: number, role: string): Promise<void> => {
    await api.patch(`/api/admin/users/${userId}/role`, { role });
  },

  // 사용자 삭제
  deleteUser: async (userId: number): Promise<void> => {
    await api.delete(`/api/admin/users/${userId}`);
  },
};

// 주문 관리 API (spot-user /api/admin/orders → spot-order 로 프록시)
export const adminOrderApi = {
  // 전체 주문 조회 (페이징)
  getAllOrders: async (page = 0, size = 20): Promise<PageResponse<OrderResponse>> => {
    const response = await api.get<ApiResponse<PageResponse<RawOrderResponse>>>(
      `/api/admin/orders?page=${page}&size=${size}`
    );
    return normalizeOrderPage(response.data.result);
  },

  // ⚠️ 주문 상태 변경 — 백엔드에 아직 없음 (ROADMAP F2-3). 생기기 전까지 404.
  updateOrderStatus: async (orderId: string, status: string): Promise<void> => {
    await api.patch(`/api/orders/${orderId}/status`, { status });
  },
};

// 가게 관리 API
export const adminStoreApi = {
  // 전체 가게 조회 (페이징, spot-user /api/admin/stores)
  getAllStores: async (page = 0, size = 20): Promise<PageResponse<Store>> => {
    const response = await api.get<ApiResponse<PageResponse<Store>>>(
      `/api/admin/stores?page=${page}&size=${size}`
    );
    return response.data.result;
  },

  // 특정 가게 조회 (spot-store, ApiResponse 래핑 없음)
  getStore: async (storeId: string): Promise<Store> => {
    const response = await api.get<Store>(`/api/stores/${storeId}`);
    return response.data;
  },

  // 가게 상태 변경 (spot-store PATCH /api/stores/{id}/status?status=)
  updateStoreStatus: async (storeId: string, status: 'PENDING' | 'APPROVED' | 'REJECTED'): Promise<void> => {
    await api.patch(`/api/stores/${storeId}/status?status=${status}`);
  },

  // 가게 승인
  approveStore: async (storeId: string): Promise<void> => {
    await api.patch(`/api/stores/${storeId}/status?status=APPROVED`);
  },

  // 가게 거절
  rejectStore: async (storeId: string): Promise<void> => {
    await api.patch(`/api/stores/${storeId}/status?status=REJECTED`);
  },

  // 가게 정보 수정 — 백엔드는 PATCH (PUT 매핑 없음)
  updateStore: async (storeId: string, storeData: StoreUpdateRequest): Promise<void> => {
    await api.patch(`/api/stores/${storeId}`, storeData);
  },

  // 가게 삭제 (spot-user /api/admin/stores/{id})
  deleteStore: async (storeId: string): Promise<void> => {
    await api.delete(`/api/admin/stores/${storeId}`);
  },
};

// 통계 및 대시보드 API (spot-user /api/admin/stats)
export const adminStatsApi = {
  // 전체 통계 조회
  getStats: async (): Promise<AdminStats> => {
    const response = await api.get<ApiResponse<AdminStats & { recentOrders?: RawOrderResponse[] }>>(
      '/api/admin/stats/dashboard'
    );
    const stats = response.data.result;
    return {
      ...stats,
      totalRevenue: Number(stats.totalRevenue ?? 0),
      recentOrders: (stats.recentOrders ?? []).map(normalizeOrder),
      userGrowth: stats.userGrowth ?? [],
      orderStats: stats.orderStats ?? [],
    };
  },
};
