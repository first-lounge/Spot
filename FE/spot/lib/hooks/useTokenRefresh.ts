'use client';

import {useEffect, useRef} from 'react';
import {authApi} from '../auth';
import {useAuthStore} from '@/store/authStore';

/**
 * 10분마다 토큰을 체크하고 필요하면 자동으로 갱신하는 Hook
 * @param intervalMinutes - 체크 주기 (기본 10분)
 */
export function useTokenRefresh(intervalMinutes: number = 10) {
  const { user, actions } = useAuthStore();
  const intervalRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    // 로그인하지 않은 사용자는 체크하지 않음
    if (!user) {
      return;
    }

    // 즉시 한 번 체크
    const checkAndRefresh = async () => {
      const success = await authApi.refreshIfNeeded();

      if (!success) {
        // 갱신 실패 시 로그아웃 처리
        actions.logout();
      }
    };

    // 최초 실행
    checkAndRefresh();

    // 주기적으로 체크 (10분마다)
    intervalRef.current = setInterval(checkAndRefresh, intervalMinutes * 60 * 1000);

    // 클린업
    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [user, intervalMinutes, actions]);
}
