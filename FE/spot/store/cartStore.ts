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
        console.log('[CartStore] addItem 호출됨:', {
          storeId,
          storeName,
          menu,
          menuId: menu?.id,
          quantity,
          options
        });

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

        console.log('[CartStore] 생성된 아이템:', newItem);

        if (!currentCart) {
          const newCart = {
            storeId,
            storeName,
            items: [newItem],
          };
          console.log('[CartStore] 새 장바구니 생성:', newCart);
          set({ cart: newCart });
          return;
        }

        // 같은 메뉴가 있으면 수량 추가
        const existingIndex = currentCart.items.findIndex(
          (item) =>
            item.menu.id === menu.id &&
            JSON.stringify(item.selectedOptions) === JSON.stringify(options)
        );

        if (existingIndex >= 0) {
          const updatedItems = [...currentCart.items];
          updatedItems[existingIndex].quantity += quantity;
          console.log('[CartStore] 기존 아이템 수량 증가:', updatedItems[existingIndex]);
          set({ cart: { ...currentCart, items: updatedItems } });
        } else {
          const updatedCart = {
            ...currentCart,
            items: [...currentCart.items, newItem],
          };
          console.log('[CartStore] 새 아이템 추가:', updatedCart);
          set({ cart: updatedCart });
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
          console.log('[CartStore] Rehydration 시작, 복원된 데이터:', state);

          // 복원된 데이터 검증
          if (state?.cart?.items) {
            const invalidItems = state.cart.items.filter(
              (item: any) => !item[0].menu || !item.menu[0].id
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
