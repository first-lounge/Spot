import Cookies from 'js-cookie';

/**
 * 토큰 저장소 — 저장 위치를 한 곳(쿠키)으로 통일한다.
 *
 * 이전에는 쿠키와 localStorage 양쪽에 같은 토큰을 저장했다.
 * 두 곳에 있으면 XSS로 훔칠 자리도 두 곳이고, 한쪽만 지워지는 버그도 생긴다.
 * httpOnly 쿠키는 JS로 만들 수 없으므로(서버가 Set-Cookie 해야 함),
 * 지금 할 수 있는 최선은 secure + sameSite 플래그를 붙이는 것이다.
 */

const ACCESS_KEY = 'accessToken';
const REFRESH_KEY = 'refreshToken';

// 서버가 발급하는 만료와 맞춤 (access 30분 / refresh 14일)
const ACCESS_EXPIRES_DAYS = 1 / 48;
const REFRESH_EXPIRES_DAYS = 14;

const cookieOptions = (): Cookies.CookieAttributes => ({
  sameSite: 'strict',
  // http://localhost 에서 secure=true 를 주면 브라우저가 쿠키 저장을 거부한다.
  secure: typeof window !== 'undefined' && window.location.protocol === 'https:',
  path: '/',
});

export const tokenStore = {
  getAccess: (): string | undefined => Cookies.get(ACCESS_KEY),

  getRefresh: (): string | undefined => Cookies.get(REFRESH_KEY),

  /** 둘 중 전달된 것만 갱신한다. */
  set: (accessToken?: string, refreshToken?: string): void => {
    if (accessToken) {
      Cookies.set(ACCESS_KEY, accessToken, { ...cookieOptions(), expires: ACCESS_EXPIRES_DAYS });
    }
    if (refreshToken) {
      Cookies.set(REFRESH_KEY, refreshToken, { ...cookieOptions(), expires: REFRESH_EXPIRES_DAYS });
    }
  },

  clear: (): void => {
    Cookies.remove(ACCESS_KEY, { path: '/' });
    Cookies.remove(REFRESH_KEY, { path: '/' });

    // 예전 버전이 localStorage에 남겨둔 토큰까지 정리
    if (typeof window !== 'undefined') {
      try {
        window.localStorage.removeItem(ACCESS_KEY);
        window.localStorage.removeItem(REFRESH_KEY);
      } catch {
        // 프라이빗 모드 등에서 접근 불가 — 무시
      }
    }
  },
};

export default tokenStore;
