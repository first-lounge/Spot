// SPOT-USER: Authentication Scenarios
import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';
import { env, endpoints, buildUrl } from '../../config/index.js';
import { getAuthHeaders, getPublicHeaders } from '../../lib/auth.js';
import { checkResponse, thinkTime, randomString, randomEmail } from '../../lib/helpers.js';

// Custom Metrics
const loginDuration = new Trend('user_login_duration');
const loginErrors = new Rate('user_login_errors');
const joinDuration = new Trend('user_join_duration');
const joinErrors = new Rate('user_join_errors');
const refreshDuration = new Trend('user_refresh_duration');
const logoutDuration = new Trend('user_logout_duration');

/**
 * Login Test
 */
export function testLogin(userType = 'customer') {
  const user = env.users[userType];
  const payload = JSON.stringify({
    username: user.username,
    password: user.password,
  });

  const res = http.post(buildUrl(endpoints.user.login), payload, {
    headers: getPublicHeaders(),
    tags: { name: 'POST /api/login', userType },
  });

  const success = check(res, {
    'login: status is 200': (r) => r.status === 200,
    'login: has accessToken': (r) => {
      try {
        return JSON.parse(r.body).accessToken !== undefined;
      } catch {
        return false;
      }
    },
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'login: response time < 300ms': (r) => r.timings.duration < 300 });

  loginDuration.add(res.timings.duration);
  loginErrors.add(!success);

  if (success) {
    return JSON.parse(res.body);
  }
  return null;
}

/**
 * Join (Registration) Test
 */
export function testJoin() {
  const username = `test_${randomString(8)}`;
  const payload = JSON.stringify({
    username: username,
    password: 'testPassword123!',
    nickname: `TestUser_${randomString(4)}`,
    email: randomEmail(),
    phone: `010${Math.floor(Math.random() * 90000000 + 10000000)}`,
  });

  const res = http.post(buildUrl(endpoints.user.join), payload, {
    headers: getPublicHeaders(),
    tags: { name: 'POST /api/join' },
  });

  const success = check(res, {
    'join: status is 200 or 201': (r) => r.status === 200 || r.status === 201,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'join: response time < 500ms': (r) => r.timings.duration < 500 });

  joinDuration.add(res.timings.duration);
  joinErrors.add(!success);

  return { success, username };
}

/**
 * Token Refresh Test
 */
export function testRefreshToken(refreshToken) {
  const payload = JSON.stringify({ refreshToken });

  const res = http.post(buildUrl(endpoints.user.refresh), payload, {
    headers: getPublicHeaders(),
    tags: { name: 'POST /api/auth/refresh' },
  });

  const success = check(res, {
    'refresh: status is 200': (r) => r.status === 200,
    'refresh: has new accessToken': (r) => {
      try {
        return JSON.parse(r.body).accessToken !== undefined;
      } catch {
        return false;
      }
    },
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'refresh: response time < 200ms': (r) => r.timings.duration < 200 });

  refreshDuration.add(res.timings.duration);

  if (success) {
    return JSON.parse(res.body);
  }
  return null;
}

/**
 * Logout Test
 */
export function testLogout(accessToken) {
  const res = http.post(buildUrl(endpoints.user.logout), null, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'POST /api/auth/logout' },
  });

  const success = check(res, {
    'logout: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'logout: response time < 200ms': (r) => r.timings.duration < 200 });

  logoutDuration.add(res.timings.duration);
  return success;
}

/**
 * Full Authentication Flow Test
 */
export function authenticationFlow() {
  group('Authentication Flow', () => {
    // 1. Login
    const loginResult = testLogin('customer');
    if (!loginResult) {
      console.error('Login failed, skipping rest of auth flow');
      return;
    }
    thinkTime(1);

    // 2. Refresh Token
    const refreshResult = testRefreshToken(loginResult.refreshToken);
    thinkTime(0.5);

    // 3. Logout
    if (refreshResult) {
      testLogout(refreshResult.accessToken);
    } else {
      testLogout(loginResult.accessToken);
    }
  });
}

export default authenticationFlow;
