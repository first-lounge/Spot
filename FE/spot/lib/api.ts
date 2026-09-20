import axios, {AxiosError, InternalAxiosRequestConfig} from 'axios';
import {tokenStore} from './token';

// Next.js rewrite 프록시를 사용하므로 baseURL 없이 상대 경로 사용
export const api = axios.create({
  headers: {
    'Content-Type': 'application/json',
  },
});

// 요청 인터셉터 - 토큰 추가 (토큰이 있을 때만)
api.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = tokenStore.getAccess();
    // 토큰이 있으면 헤더에 추가, 없어도 요청은 진행
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// 401 에러 시 로그인 리다이렉트를 하지 않을 경로들
const publicPaths = ['/api/stores', '/api/categories', '/api/menus'];

const isPublicPath = (url: string | undefined): boolean => {
  if (!url) return false;
  return publicPaths.some((path) => url.startsWith(path));
};

const redirectToLogin = () => {
  if (typeof window !== 'undefined' && !window.location.pathname.includes('/login')) {
    window.location.href = '/login';
  }
};

// 동시에 여러 요청이 401을 받아도 refresh 는 한 번만 보낸다
let refreshPromise: Promise<string> | null = null;

const refreshAccessToken = async (refreshToken: string): Promise<string> => {
  if (!refreshPromise) {
    refreshPromise = axios
      .post('/api/auth/refresh', { refreshToken })
      .then((response) => {
        // 백엔드 AuthTokenController 는 TokenPairResponse 를 ApiResponse 로 감싸지 않고 그대로 준다.
        // 예전 코드가 `.result` 를 읽어 갱신이 항상 조용히 실패했음 → 두 형태 모두 허용
        const body = response.data?.result ?? response.data;
        const accessToken: string | undefined = body?.accessToken;
        const newRefreshToken: string | undefined = body?.refreshToken;
        if (!accessToken) {
          throw new Error('토큰 갱신 응답에 accessToken 이 없습니다.');
        }
        tokenStore.set(accessToken, newRefreshToken);
        return accessToken;
      })
      .finally(() => {
        refreshPromise = null;
      });
  }
  return refreshPromise;
};

// 응답 인터셉터 - 토큰 만료 처리
api.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };

    if (error.response?.status !== 401) {
      return Promise.reject(error);
    }

    // 공개 경로는 401 에러가 발생해도 로그인 리다이렉트 하지 않음
    if (isPublicPath(originalRequest.url)) {
      return Promise.reject(error);
    }

    // 이미 한 번 재시도한 요청이면 더 이상 시도하지 않음
    if (originalRequest._retry) {
      return Promise.reject(error);
    }
    originalRequest._retry = true;

    const refreshToken = tokenStore.getRefresh();
    if (!refreshToken) {
      redirectToLogin();
      return Promise.reject(error);
    }

    try {
      const accessToken = await refreshAccessToken(refreshToken);
      if (originalRequest.headers) {
        originalRequest.headers.Authorization = `Bearer ${accessToken}`;
      }
      return api(originalRequest);
    } catch (refreshError) {
      // 리프레시 토큰도 만료된 경우
      tokenStore.clear();
      if (typeof window !== 'undefined') {
        try {
          window.localStorage.removeItem('auth-storage');
        } catch {
          // 무시
        }
      }
      redirectToLogin();
      return Promise.reject(refreshError);
    }
  }
);

/**
 * catch 블록에서 사용자에게 보여줄 메시지를 뽑는다.
 * 서버가 ApiResponse.message 를 주면 그걸, 아니면 fallback.
 */
export const getApiErrorMessage = (error: unknown, fallback: string): string => {
  if (axios.isAxiosError(error)) {
    return error.response?.data?.message || fallback;
  }
  return fallback;
};

export default api;
