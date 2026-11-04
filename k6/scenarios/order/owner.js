// SPOT-ORDER: Owner Order Management Scenarios
import http from 'k6/http';
import { check, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';
import { endpoints, buildUrl } from '../../config/index.js';
import { getAuthHeaders } from '../../lib/auth.js';
import { thinkTime, buildQueryString } from '../../lib/helpers.js';

// Custom Metrics
const storeOrderListDuration = new Trend('store_order_list_duration');
const storeOrderListErrors = new Rate('store_order_list_errors');
const storeOrderActiveDuration = new Trend('store_order_active_duration');
const orderAcceptDuration = new Trend('order_accept_duration');
const orderRejectDuration = new Trend('order_reject_duration');
const orderCompleteDuration = new Trend('order_complete_duration');

/**
 * Get My Store Orders (Owner)
 */
export function testGetMyStoreOrders(accessToken, params = {}) {
  const queryString = buildQueryString({
    customerId: params.customerId,
    date: params.date,
    status: params.status,
    page: params.page || 0,
    size: params.size || 10,
    sortBy: params.sortBy || 'createdAt',
    direction: params.direction || 'DESC',
  });

  const res = http.get(buildUrl(endpoints.order.getMyStoreOrders) + queryString, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/orders/my-store' },
  });

  const success = check(res, {
    'getMyStoreOrders: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getMyStoreOrders: response time < 500ms': (r) => r.timings.duration < 500 });

  storeOrderListDuration.add(res.timings.duration);
  storeOrderListErrors.add(!success);

  return success ? JSON.parse(res.body) : null;
}

/**
 * Get My Store Active Orders (Owner)
 */
export function testGetMyStoreActiveOrders(accessToken) {
  const res = http.get(buildUrl(endpoints.order.getMyStoreActiveOrders), {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/orders/my-store/active' },
  });

  const success = check(res, {
    'getMyStoreActiveOrders: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getMyStoreActiveOrders: response time < 500ms': (r) => r.timings.duration < 500 });

  storeOrderActiveDuration.add(res.timings.duration);
  return success ? JSON.parse(res.body) : null;
}

/**
 * Accept Order (Owner)
 */
export function testAcceptOrder(accessToken, orderId, acceptData) {
  const payload = JSON.stringify(acceptData || {
    estimatedMinutes: 30,
  });

  const res = http.patch(buildUrl(endpoints.order.acceptOrder(orderId)), payload, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'PATCH /api/orders/{orderId}/accept' },
  });

  const success = check(res, {
    'acceptOrder: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'acceptOrder: response time < 500ms': (r) => r.timings.duration < 500 });

  orderAcceptDuration.add(res.timings.duration);
  return success;
}

/**
 * Reject Order (Owner)
 */
export function testRejectOrder(accessToken, orderId, rejectData) {
  const payload = JSON.stringify(rejectData || {
    reason: 'Store is too busy',
  });

  const res = http.patch(buildUrl(endpoints.order.rejectOrder(orderId)), payload, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'PATCH /api/orders/{orderId}/reject' },
  });

  const success = check(res, {
    'rejectOrder: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'rejectOrder: response time < 500ms': (r) => r.timings.duration < 500 });

  orderRejectDuration.add(res.timings.duration);
  return success;
}

/**
 * Complete Order (Owner)
 */
export function testCompleteOrder(accessToken, orderId) {
  const res = http.patch(buildUrl(endpoints.order.completeOrder(orderId)), null, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'PATCH /api/orders/{orderId}/complete' },
  });

  const success = check(res, {
    'completeOrder: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'completeOrder: response time < 500ms': (r) => r.timings.duration < 500 });

  orderCompleteDuration.add(res.timings.duration);
  return success;
}

/**
 * Owner Order Management Flow
 */
export function ownerOrderManagementFlow(accessToken) {
  group('Owner Order Management Flow', () => {
    // 1. Check active orders
    const activeOrders = testGetMyStoreActiveOrders(accessToken);
    thinkTime(0.5);

    // 2. View order history
    testGetMyStoreOrders(accessToken, { page: 0, size: 10 });
    thinkTime(1);

    // Note: Accepting/rejecting orders might affect data
    // if (activeOrders && activeOrders.length > 0) {
    //   testAcceptOrder(accessToken, activeOrders[0].orderId);
    // }
  });
}

export default ownerOrderManagementFlow;
