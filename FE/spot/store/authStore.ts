import {create} from 'zustand';
import {createJSONStorage, persist} from 'zustand/middleware';
import {tokenStore} from '@/lib/token';
import {useCartStore} from '@/store/cartStore';
import type {Role, User} from '@/types';

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  hasHydrated: boolean;

  actions: {
    setUser: (user: User | null) => void;
    logout: () => void;
    setHasHydrated: (value: boolean) => void;
  };
  // Selectors (상태 기반 계산 함수)
  hasRole: (roles: Role[]) => boolean;
}

// SSR 환경에서 안전한 스토리지 생성
const getStorage = () => {
  if (typeof window !== 'undefined') {
    return window.localStorage;
  }
  // SSR 환경에서는 빈 스토리지 반환
  return {
    getItem: () => null,
    setItem: () => {},
    removeItem: () => {},
  };
};

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      isAuthenticated: false,
      isLoading: true,
      hasHydrated: false,

      actions: {
        setUser: (user) => {
          set({ user, isAuthenticated: !!user, isLoading: false });
        },
        logout: () => {
          tokenStore.clear();
          set({ user: null, isAuthenticated: false });

          // 장바구니는 사용자 소유 — 로그아웃하면 같이 비운다
          // (예전엔 안 비워서 다음 로그인 때 이전 세션의 장바구니가 그대로 보였음)
          useCartStore.getState().clearCart();

          // persist 가 남긴 사용자 정보도 제거
          if (typeof window !== 'undefined') {
            try {
              window.localStorage.removeItem('auth-storage');
            } catch {
              // 무시
            }
          }
        },
        setHasHydrated: (value) => {
          set({ hasHydrated: value });
        },
      },

      hasRole: (roles) => {
        const user = get().user;
        if (!user) return false;
        return roles.includes(user.role);
      },
    }),
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => getStorage()),
      partialize: (state) => ({
        user: state.user,
        isAuthenticated: state.isAuthenticated
      }),
      onRehydrateStorage: () => {
        return (_hydratedState, error) => {
          if (error) {
            console.error('[AuthStore] 저장소 복원 실패:', error);
          }
          // hydration 완료 후 상태 업데이트 (setTimeout으로 초기화 완료 후 실행)
          setTimeout(() => {
            useAuthStore.setState({ hasHydrated: true, isLoading: false });
          }, 0);
        };
      },
    }
  )
);

// 편의를 위한 Custom Hook (컴포넌트에서 깔끔하게 사용)
export const useAuth = () => useAuthStore((state) => state);
export const useAuthActions = () => useAuthStore((state) => state.actions);
