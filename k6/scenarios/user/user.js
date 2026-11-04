// SPOT-USER: User Management Scenarios
import http from 'k6/http';
import { check, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';
import { env, endpoints, buildUrl } from '../../config/index.js';
import { getAuthHeaders } from '../../lib/auth.js';
import { checkResponse, thinkTime, buildQueryString } from '../../lib/helpers.js';

// Custom Metrics
const getUserDuration = new Trend('user_get_duration');
const getUserErrors = new Rate('user_get_errors');
const updateUserDuration = new Trend('user_update_duration');
const searchUserDuration = new Trend('user_search_duration');

// Admin Metrics
const adminGetUsersDuration = new Trend('admin_get_users_duration');
const adminStatsDuration = new Trend('admin_stats_duration');

/**
 * Get User Profile
 */
export function testGetUser(accessToken, userId) {
  const res = http.get(buildUrl(endpoints.user.getUser(userId)), {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/users/{userId}' },
  });

  const success = check(res, {
    'getUser: status is 200': (r) => r.status === 200,
    'getUser: has user data': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.id !== undefined || body.userId !== undefined;
      } catch {
        return false;
      }
    },
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getUser: response time < 200ms': (r) => r.timings.duration < 200 });

  getUserDuration.add(res.timings.duration);
  getUserErrors.add(!success);

  return success ? JSON.parse(res.body) : null;
}

/**
 * Update User Profile
 */
export function testUpdateUser(accessToken, userId, updateData) {
  const payload = JSON.stringify(updateData || {
    nickname: `Updated_${Date.now()}`,
  });

  const res = http.patch(buildUrl(endpoints.user.updateUser(userId)), payload, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'PATCH /api/users/{userId}' },
  });

  const success = check(res, {
    'updateUser: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'updateUser: response time < 300ms': (r) => r.timings.duration < 300 });

  updateUserDuration.add(res.timings.duration);
  return success;
}

/**
 * Search Users (Admin/Owner)
 */
export function testSearchUsers(accessToken, nickname) {
  const queryString = buildQueryString({ nickname });
  const res = http.get(buildUrl(endpoints.user.searchUsers) + queryString, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/users/search' },
  });

  const success = check(res, {
    'searchUsers: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'searchUsers: response time < 300ms': (r) => r.timings.duration < 300 });

  searchUserDuration.add(res.timings.duration);
  return success ? JSON.parse(res.body) : null;
}

/**
 * Admin: Get All Users
 */
export function testAdminGetUsers(accessToken, params = {}) {
  const queryString = buildQueryString({
    page: params.page || 0,
    size: params.size || 20,
    sortBy: params.sortBy || 'id',
    direction: params.direction || 'ASC',
  });

  const res = http.get(buildUrl(endpoints.user.adminGetUsers) + queryString, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/admin/users' },
  });

  const success = check(res, {
    'adminGetUsers: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'adminGetUsers: response time < 500ms': (r) => r.timings.duration < 500 });

  adminGetUsersDuration.add(res.timings.duration);
  return success ? JSON.parse(res.body) : null;
}

/**
 * Admin: Get Stats
 */
export function testAdminStats(accessToken) {
  const res = http.get(buildUrl(endpoints.user.adminStats), {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/admin/stats/dashboard' },
  });

  const success = check(res, {
    'adminStats: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'adminStats: response time < 500ms': (r) => r.timings.duration < 500 });

  adminStatsDuration.add(res.timings.duration);
  return success ? JSON.parse(res.body) : null;
}

/**
 * User Management Flow
 */
export function userManagementFlow(tokens) {
  group('User Management Flow', () => {
    const customerToken = tokens.customer?.accessToken;
    const managerToken = tokens.manager?.accessToken;

    if (!customerToken) {
      console.error('Customer token not available');
      return;
    }

    // Customer: Get own profile (userId from token would be needed)
    // testGetUser(customerToken, userId);
    thinkTime(1);

    // Manager: Get all users
    if (managerToken) {
      testAdminGetUsers(managerToken, { page: 0, size: 10 });
      thinkTime(0.5);

      // Manager: Get stats
      testAdminStats(managerToken);
    }
  });
}

export default userManagementFlow;
