import axios from 'axios';
import api from './api';
import {tokenStore} from './token';
import type {ApiResponse, JoinRequest, LoginRequest, LoginResponse, Role, User} from '@/types';

export type {Role};

const decodeJwtPayload = (token: string): Record<string, unknown> => {
  const payload = token.split('.')[1];
  // base64url → base64
  const base64 = payload.replace(/-/g, '+').replace(/_/g, '/');
  // UTF-8 디코딩 대응
  return JSON.parse(decodeURIComponent(escape(window.atob(base64))));
};

export const authApi = {
  // 로그인 - Next.js 프록시를 통해 요청 (CORS 우회)
  // 공유 api 인스턴스를 쓰지 않는 이유: 401 인터셉터가 로그인 실패를 "토큰 만료"로 오해하면 안 되기 때문
  login: async (data: LoginRequest): Promise<LoginResponse> => {
    try {
      const response = await axios.post<LoginResponse>(
        '/api/login',
        {
          username: data.username,
          password: data.password,
        },
        {
          headers: {
            'Content-Type': 'application/json',
          },
        }
      );

      // 바디 우선, 없으면 헤더에서 추출 (LoginFilter는 둘 다 내려줌)
      const headerToken = (response.headers['authorization'] as string | undefined)?.replace('Bearer ', '');
      const accessToken = response.data.accessToken || headerToken;
      tokenStore.set(accessToken, response.data.refreshToken);

      return response.data;
    } catch (error: unknown) {
      if (axios.isAxiosError(error)) {
        // 401 Unauthorized - 로그인 실패
        if (error.response?.status === 401) {
          throw new Error(error.response?.data?.message || '아이디 또는 비밀번호가 올바르지 않습니다.');
        }

        // 네트워크 에러
        if (error.code === 'ECONNREFUSED' || error.message.includes('Network Error')) {
          throw new Error('서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.');
        }

        throw new Error(error.response?.data?.message || '로그인 중 오류가 발생했습니다.');
      }

      throw new Error('로그인 중 오류가 발생했습니다.');
    }
  },

  // 회원가입
  join: async (data: JoinRequest): Promise<ApiResponse<void>> => {
    const response = await api.post<ApiResponse<void>>('/api/join', data);
    return response.data;
  },

  // 로그아웃
  // 서버는 stateless 라 실질 동작은 없고, 게이트웨이에 라우트가 없어 404가 날 수 있다.
  // 어느 쪽이든 클라이언트 토큰은 반드시 지운다.
  logout: async (): Promise<void> => {
    try {
      await api.post('/api/auth/logout');
    } catch {
      // 서버 응답과 무관하게 진행
    } finally {
      tokenStore.clear();
    }
  },

  // 회원 탈퇴 (본인)
  deleteMe: async (): Promise<void> => {
    await api.delete('/api/users/me');
    tokenStore.clear();
  },

  // 토큰 갱신 — 백엔드는 TokenPairResponse 를 그대로 준다(ApiResponse 래핑 없음). 두 형태 모두 허용
  refresh: async (refreshToken: string): Promise<LoginResponse> => {
    const response = await api.post<LoginResponse | ApiResponse<LoginResponse>>('/api/auth/refresh', {
      refreshToken,
    });
    const body = response.data as Partial<ApiResponse<LoginResponse>> & Partial<LoginResponse>;
    const tokens = body.result ?? (body as LoginResponse);
    if (!tokens?.accessToken) {
      throw new Error('토큰 갱신 응답에 accessToken 이 없습니다.');
    }
    return tokens;
  },

  // 현재 사용자 정보 조회
  getMe: async (userId: number): Promise<User> => {
    const response = await api.get<User>(`/api/users/${userId}`);
    return response.data;
  },

  // 토큰에서 사용자 정보 파싱 (JWT 디코딩 — 서명 검증은 서버 몫, 여기선 표시용)
  parseToken: (token: string): { userId: number; role: Role } | null => {
    try {
      const decoded = decodeJwtPayload(token);
      return {
        // sub가 문자열로 올 수 있으므로 숫자로 변환
        userId: Number(decoded.userId ?? decoded.sub),
        role: decoded.role as Role,
      };
    } catch {
      return null;
    }
  },

  // 로그인 상태 확인
  isAuthenticated: (): boolean => {
    return !!tokenStore.getAccess();
  },

  // 토큰 만료 확인 (만료 5분 전이면 true 반환)
  isTokenExpiringSoon: (token: string, thresholdMinutes: number = 5): boolean => {
    try {
      const exp = decodeJwtPayload(token).exp as number | undefined;
      if (!exp) return true;

      const now = Math.floor(Date.now() / 1000);
      return exp - now <= thresholdMinutes * 60;
    } catch {
      return true;
    }
  },

  // 토큰 자동 갱신 (access 가 없거나 만료가 임박하면 refresh)
  // 반환값: true = 유효한 access 토큰이 있다 / false = 갱신 불가(로그아웃 대상)
  refreshIfNeeded: async (): Promise<boolean> => {
    const accessToken = tokenStore.getAccess();
    const refreshToken = tokenStore.getRefresh();

    // refresh 토큰이 없으면 갱신할 수단이 없다
    if (!refreshToken) {
      return false;
    }

    // access 쿠키가 만료로 사라졌어도 refresh 가 있으면 갱신한다 (예전엔 여기서 false → 로그아웃)
    if (accessToken && !authApi.isTokenExpiringSoon(accessToken, 5)) {
      return true;
    }

    try {
      const response = await authApi.refresh(refreshToken);
      tokenStore.set(response.accessToken, response.refreshToken);
      return true;
    } catch {
      // 갱신 실패 시 토큰 삭제
      tokenStore.clear();
      return false;
    }
  },
};

export default authApi;
