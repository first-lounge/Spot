import api from './api';
import type {
  ApiResponse,
  Category,
  PageResponse,
  Store,
  StoreCreateRequest,
  StoreUpdateRequest,
} from '@/types';

/**
 * 백엔드 응답이 ApiResponse<T>로 감싸져 오는 엔드포인트와
 * T를 그대로 주는 엔드포인트가 섞여 있어, 둘 다 받아들인다.
 */
const unwrap = <T>(data: ApiResponse<T> | T): T => {
  if (data && typeof data === 'object' && 'result' in (data as object) && 'isSuccess' in (data as object)) {
    return (data as ApiResponse<T>).result;
  }
  return data as T;
};

export const storeApi = {
  // 가게 목록 조회
  getStores: async (page = 0, size = 20): Promise<PageResponse<Store>> => {
    const response = await api.get<PageResponse<Store>>('/api/stores', {
      params: { page, size },
    });
    return response.data;
  },

  // 가게 상세 조회
  getStore: async (storeId: string): Promise<Store> => {
    const response = await api.get<Store>(`/api/stores/${storeId}`);
    return response.data;
  },

  // 내 가게 목록 조회 (OWNER)
  getMyStores: async (): Promise<Store[]> => {
    const response = await api.get<ApiResponse<Store[]> | Store[]>('/api/stores/my');
    const stores = unwrap(response.data);
    return Array.isArray(stores) ? stores : [];
  },

  // 가게 등록 (OWNER) — 관리자 승인 전까지 PENDING
  createStore: async (data: StoreCreateRequest): Promise<void> => {
    await api.post('/api/stores', data);
  },

  // 가게 정보 수정 (OWNER / 관리자) — 백엔드는 PATCH /api/stores/{id}
  updateStore: async (storeId: string, data: StoreUpdateRequest): Promise<void> => {
    await api.patch(`/api/stores/${storeId}`, data);
  },

  // 가게 삭제 / 등록 취소 (OWNER)
  deleteStore: async (storeId: string): Promise<void> => {
    await api.delete(`/api/stores/${storeId}`);
  },

  // 가게 검색
  searchStores: async (keyword: string, page = 0, size = 20): Promise<PageResponse<Store>> => {
    const response = await api.get<PageResponse<Store>>('/api/stores/search', {
      params: { keyword, page, size },
    });
    return response.data;
  },

  // 카테고리 목록 조회
  getCategories: async (): Promise<Category[]> => {
    const response = await api.get<Category[]>('/api/categories');
    return response.data;
  },

  // 카테고리 생성 (OWNER / 관리자)
  createCategory: async (name: string): Promise<void> => {
    await api.post('/api/categories', { name });
  },

  // 카테고리별 가게 조회
  getStoresByCategory: async (categoryName: string): Promise<PageResponse<Store>> => {
    const response = await api.get<Store[]>(
      `/api/categories/${categoryName}/stores`
    );
    // 백엔드가 List로 반환하므로 PageResponse 형태로 변환
    const stores = response.data;
    return {
      content: stores,
      totalPages: 1,
      totalElements: stores.length,
      size: stores.length,
      number: 0,
    };
  },
};

export default storeApi;
