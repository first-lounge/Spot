// SPOT-ORDER: Chef Order Management Scenarios
import http from 'k6/http';
import { check, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';
import { endpoints, buildUrl } from '../../config/index.js';
import { getAuthHeaders } from '../../lib/auth.js';
import { thinkTime } from '../../lib/helpers.js';

// Custom Metrics
const chefTodayOrdersDuration = new Trend('chef_today_orders_duration');
const chefTodayOrdersErrors = new Rate('chef_today_orders_errors');
const startCookingDuration = new Trend('order_start_cooking_duration');
const readyOrderDuration = new Trend('order_ready_duration');

/**
 * Get Chef Today Orders
 */
export function testGetChefTodayOrders(accessToken) {
  const res = http.get(buildUrl(endpoints.order.getChefTodayOrders), {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/orders/chef/today' },
  });

  const success = check(res, {
    'getChefTodayOrders: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getChefTodayOrders: response time < 500ms': (r) => r.timings.duration < 500 });

  chefTodayOrdersDuration.add(res.timings.duration);
  chefTodayOrdersErrors.add(!success);

  return success ? JSON.parse(res.body) : null;
}

/**
 * Start Cooking Order (Chef)
 */
export function testStartCooking(accessToken, orderId) {
  const res = http.patch(buildUrl(endpoints.order.startCooking(orderId)), null, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'PATCH /api/orders/{orderId}/start-cooking' },
  });

  const success = check(res, {
    'startCooking: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'startCooking: response time < 500ms': (r) => r.timings.duration < 500 });

  startCookingDuration.add(res.timings.duration);
  return success;
}

/**
 * Mark Order Ready for Pickup (Chef)
 */
export function testReadyOrder(accessToken, orderId) {
  const res = http.patch(buildUrl(endpoints.order.readyOrder(orderId)), null, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'PATCH /api/orders/{orderId}/ready' },
  });

  const success = check(res, {
    'readyOrder: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'readyOrder: response time < 500ms': (r) => r.timings.duration < 500 });

  readyOrderDuration.add(res.timings.duration);
  return success;
}

/**
 * Chef Order Management Flow
 */
export function chefOrderManagementFlow(accessToken) {
  group('Chef Order Management Flow', () => {
    // 1. Get today's orders
    const todayOrders = testGetChefTodayOrders(accessToken);
    thinkTime(1);

    // Note: Starting cooking might affect data
    // if (todayOrders && todayOrders.length > 0) {
    //   const orderId = todayOrders[0].orderId;
    //   testStartCooking(accessToken, orderId);
    //   thinkTime(2);
    //   testReadyOrder(accessToken, orderId);
    // }
  });
}

export default chefOrderManagementFlow;
