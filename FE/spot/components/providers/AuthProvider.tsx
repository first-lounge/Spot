'use client';

import {useEffect} from 'react';
import {useTokenRefresh} from '@/lib/hooks/useTokenRefresh';
import {useAuthStore} from '@/store/authStore';
import {useCartStore} from '@/store/cartStore';
import {authApi} from '@/lib/auth';
import {tokenStore} from '@/lib/token';

/**
 * 인증 관련 전역 로직을 처리하는 Provider
 * - 토큰 자동 갱신 (10분마다)
 * - 초기 인증 상태 복원
 */
export function AuthProvider({ children }: { children: React.ReactNode }) {
  const { user, hasHydrated, actions } = useAuthStore();

  // 10분마다 토큰 갱신 체크
  useTokenRefresh(10);

  // 로그인한 사용자에게 장바구니 귀속 (다른 계정의 장바구니면 비움)
  const userId = user?.id;
  const cartHydrated = useCartStore((state) => state.hasHydrated);
  useEffect(() => {
    if (userId == null || !cartHydrated) return;
    useCartStore.getState().claimCart(userId);
  }, [userId, cartHydrated]);

  // 초기 마운트 시 토큰 유효성 검증
  useEffect(() => {
    if (!hasHydrated) return;

    const validateInitialAuth = async () => {
      let accessToken = tokenStore.getAccess();
      const storedUser = user;

      // access 쿠키는 30분 뒤 사라지지만 refresh 쿠키는 14일 남아 있다.
      // 예전 코드는 access 가 없으면 곧바로 로그아웃시켜서, 탭을 닫았다 30분 뒤 열면
      // 유효한 refresh 토큰이 있어도 로그인이 풀렸다. → 먼저 갱신을 시도한다.
      if (!accessToken && tokenStore.getRefresh()) {
        const refreshed = await authApi.refreshIfNeeded();
        accessToken = refreshed ? tokenStore.getAccess() : undefined;
      }

      // 토큰은 있지만 유저 정보가 없는 경우 → 서버에서 복원
      if (accessToken && !storedUser) {
        try {
          const tokenInfo = authApi.parseToken(accessToken);
          if (tokenInfo && tokenInfo.userId) {
            const userData = await authApi.getMe(tokenInfo.userId);
            actions.setUser(userData);
          }
        } catch (error) {
          console.error('[AuthProvider] 초기 인증 복원 실패:', error);
          actions.logout();
        }
      }
      // 갱신까지 실패해 토큰이 없는데 유저 정보만 남은 경우 → 정리
      else if (!accessToken && storedUser) {
        actions.logout();
      }
    };

    validateInitialAuth();
  }, [hasHydrated, user, actions]);

  return <>{children}</>;
}
