import api from './api';
import type {ApiResponse, Menu, MenuOption} from '@/types';

export interface CreateMenuRequest {
  name: string;
  category: string;
  price: number;
  description: string;
  imageUrl?: string;
  isAvailable?: boolean;
  isHidden?: boolean;
}

export interface CreateMenuOptionRequest {
  name: string;
  detail: string;
  price: number;
}

export const menuApi = {
  // 가게의 메뉴 목록 조회
  getMenus: async (storeId: string): Promise<Menu[]> => {
    const response = await api.get<ApiResponse<Menu[]>>(`/api/stores/${storeId}/menus`);
    return response.data.result;
  },

  // 메뉴 상세 조회
  getMenu: async (storeId: string, menuId: string): Promise<Menu> => {
    const response = await api.get<ApiResponse<Menu>>(
      `/api/stores/${storeId}/menus/${menuId}`
    );
    return response.data.result;
  },

  // 메뉴 생성
  createMenu: async (storeId: string, menuData: CreateMenuRequest): Promise<Menu> => {
    // imageUrl이 비어있거나 null, undefined이면 기본 이미지 설정
    const defaultImageUrl = 'https://via.placeholder.com/300x200?text=Menu+Image';
    const requestData = {
      ...menuData,
      imageUrl: menuData.imageUrl?.trim() || defaultImageUrl,
    };

    const response = await api.post<ApiResponse<Menu>>(
      `/api/stores/${storeId}/menus`,
      requestData
    );
    return response.data.result;
  },

  // 메뉴 수정
  updateMenu: async (storeId: string, menuId: string, menuData: Partial<CreateMenuRequest>): Promise<void> => {
    // imageUrl이 비어있거나 null, undefined이면 기본 이미지 설정
    const defaultImageUrl = 'https://via.placeholder.com/300x200?text=Menu+Image';
    const requestData = {
      ...menuData,
      imageUrl: menuData.imageUrl?.trim() || defaultImageUrl,
    };

    // 백엔드 MenuController 는 @PatchMapping — PUT 이면 405
    await api.patch(`/api/stores/${storeId}/menus/${menuId}`, requestData);
  },

  // 메뉴 삭제
  deleteMenu: async (storeId: string, menuId: string): Promise<void> => {
    await api.delete(`/api/stores/${storeId}/menus/${menuId}`);
  },

  // 메뉴 옵션 추가
  addMenuOption: async (storeId: string, menuId: string, optionData: CreateMenuOptionRequest): Promise<MenuOption> => {
    if (!menuId || menuId === 'undefined') {
      throw new Error(`유효하지 않은 menuId: ${menuId}`);
    }

    const response = await api.post<ApiResponse<MenuOption>>(
      `/api/stores/${storeId}/menus/${menuId}/options`,
      optionData
    );
    return response.data.result;
  },

  // 메뉴 옵션 수정
  updateMenuOption: async (storeId: string, menuId: string, optionId: string, optionData: Partial<CreateMenuOptionRequest>): Promise<void> => {
    // 백엔드 MenuOptionController 는 @PatchMapping — PUT 이면 405
    await api.patch(`/api/stores/${storeId}/menus/${menuId}/options/${optionId}`, optionData);
  },

  // 메뉴 옵션 삭제
  deleteMenuOption: async (storeId: string, menuId: string, optionId: string): Promise<void> => {
    await api.delete(`/api/stores/${storeId}/menus/${menuId}/options/${optionId}`);
  },
};

export default menuApi;
