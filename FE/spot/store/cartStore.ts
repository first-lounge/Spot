import {create} from 'zustand';
import {createJSONStorage, persist} from 'zustand/middleware';
import type {Cart, CartItem, Menu, MenuOption} from '@/types';

// SSR 환경에서 안전한 스토리지 생성
const getStorage = () => {
  if (typeof window !== 'undefined') {
    return window.localStorage;
  }
  return {
    getItem: () => null,
    setItem: () => {},
    removeItem: () => {},
  };
};

interface CartState {
  cart: Cart | null;
  hasHydrated: boolean;
  addItem: (storeId: string, storeName: string, menu: Menu, quantity: number, options: MenuOption[]) => void;
  removeItem: (menuId: string) => void;
  updateQuantity: (menuId: string, quantity: number) => void;
  clearCart: () => void;
  /**
   * 로그인한 사용자에게 장바구니를 귀속시킨다.
   * - 주인이 없으면(비로그인 때 담음) 이 사용자 것으로
   * - 다른 사용자 것이면 비운다 (같은 브라우저에서 계정을 바꿔 로그인한 경우)
   */
  claimCart: (userId: number) => void;
  getTotal: () => number;
  getItemCount: () => number;
  setHasHydrated: (value: boolean) => void;
}

export const useCartStore = create<CartState>()(
  persist(
    (set, get) => ({
      cart: null,
      hasHydrated: false,

      setHasHydrated: (value) => set({ hasHydrated: value }),

      addItem: (storeId, storeName, menu, quantity, options) => {
        const { cart } = get();

        // 다른 가게의 메뉴가 있으면 장바구니 비우기
        if (cart && cart.storeId !== storeId) {
          const confirm = window.confirm(
            '다른 가게의 메뉴가 장바구니에 있습니다. 장바구니를 비우고 새로 담으시겠습니까?'
          );
          if (!confirm) return;
          set({ cart: null });
        }

        const currentCart = get().cart;
        const newItem: CartItem = { menu, quantity, selectedOptions: options };

        if (!currentCart) {
          set({ cart: { storeId, storeName, items: [newItem] } });
          return;
        }

        // 같은 메뉴가 있으면 수량 추가
        const existingIndex = currentCart.items.findIndex(
          (item) =>
            item.menu.id === menu.id &&
            JSON.stringify(item.selectedOptions) === JSON.stringify(options)
        );

        if (existingIndex >= 0) {
          // 기존 아이템 객체를 직접 수정하지 않고 새 객체로 교체 (불변성 유지)
          const updatedItems = currentCart.items.map((item, index) =>
            index === existingIndex ? { ...item, quantity: item.quantity + quantity } : item
          );
          set({ cart: { ...currentCart, items: updatedItems } });
        } else {
          set({ cart: { ...currentCart, items: [...currentCart.items, newItem] } });
        }
      },

      removeItem: (menuId) => {
        const { cart } = get();
        if (!cart) return;

        const updatedItems = cart.items.filter((item) => item.menu.id !== menuId);
        if (updatedItems.length === 0) {
          set({ cart: null });
        } else {
          set({ cart: { ...cart, items: updatedItems } });
        }
      },

      updateQuantity: (menuId, quantity) => {
        const { cart } = get();
        if (!cart) return;

        if (quantity <= 0) {
          get().removeItem(menuId);
          return;
        }

        const updatedItems = cart.items.map((item) =>
          item.menu.id === menuId ? { ...item, quantity } : item
        );
        set({ cart: { ...cart, items: updatedItems } });
      },

      clearCart: () => set({ cart: null }),

      claimCart: (userId) => {
        const { cart } = get();
        if (!cart) return;
        if (cart.userId == null) {
          set({ cart: { ...cart, userId } });
        } else if (cart.userId !== userId) {
          set({ cart: null });
        }
      },

      getTotal: () => {
        const { cart } = get();
        if (!cart) return 0;

        return cart.items.reduce((total, item) => {
          const optionsTotal = item.selectedOptions.reduce(
            (sum, opt) => sum + (opt.price || 0),
            0
          );
          return total + (item.menu.price + optionsTotal) * item.quantity;
        }, 0);
      },

      getItemCount: () => {
        const { cart } = get();
        if (!cart) return 0;
        return cart.items.reduce((count, item) => count + item.quantity, 0);
      },
    }),
    {
      name: 'cart-storage',
      storage: createJSONStorage(() => getStorage()),
      onRehydrateStorage: () => {
        return (state) => {
          // 복원된 데이터 검증
          // (이전 코드는 `item[0].menu || item.menu[0].id` 로 잘못 접근해 항상 예외가 나거나 검증이 안 됐다)
          if (state?.cart?.items) {
            const invalidItems = state.cart.items.filter(
              (item: Partial<CartItem> | null | undefined) => !item?.menu || !item.menu.id
            );

            if (invalidItems.length > 0) {
              console.error('[CartStore] 손상된 데이터 발견, 장바구니 초기화:', invalidItems);
              // 손상된 데이터 삭제
              if (typeof window !== 'undefined') {
                localStorage.removeItem('cart-storage');
              }
              useCartStore.setState({ cart: null, hasHydrated: true });
              return;
            }
          }

          // hydration 완료 후 상태 업데이트 (setTimeout으로 초기화 완료 후 실행)
          setTimeout(() => {
            useCartStore.setState({ hasHydrated: true });
          }, 0);
        };
      },
    }
  )
);

export default useCartStore;
