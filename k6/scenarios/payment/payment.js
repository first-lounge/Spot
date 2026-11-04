// SPOT-PAYMENT: Payment Scenarios
import http from 'k6/http';
import { check, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';
import { env, endpoints, buildUrl } from '../../config/index.js';
import { getAuthHeaders } from '../../lib/auth.js';
import { thinkTime } from '../../lib/helpers.js';

// Custom Metrics
const paymentConfirmDuration = new Trend('payment_confirm_duration');
const paymentConfirmErrors = new Rate('payment_confirm_errors');
const paymentCancelDuration = new Trend('payment_cancel_duration');
const paymentListDuration = new Trend('payment_list_duration');
const paymentListErrors = new Rate('payment_list_errors');
const paymentDetailDuration = new Trend('payment_detail_duration');
const billingKeyCheckDuration = new Trend('billing_key_check_duration');

/**
 * Confirm Payment (Customer)
 */
export function testConfirmPayment(accessToken, orderId, confirmData) {
  const payload = JSON.stringify(confirmData || {
    paymentKey: `test_payment_${Date.now()}`,
    amount: 10000,
  });

  const res = http.post(buildUrl(endpoints.payment.confirmPayment(orderId)), payload, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'POST /api/payments/{orderId}/confirm' },
  });

  const success = check(res, {
    'confirmPayment: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'confirmPayment: response time < 2000ms': (r) => r.timings.duration < 2000 });

  paymentConfirmDuration.add(res.timings.duration);
  paymentConfirmErrors.add(!success);

  return success ? JSON.parse(res.body) : null;
}

/**
 * Cancel Payment
 */
export function testCancelPayment(accessToken, orderId, cancelData) {
  const payload = JSON.stringify(cancelData || {
    cancelReason: 'Test cancellation',
  });

  const res = http.post(buildUrl(endpoints.payment.cancelPayment(orderId)), payload, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'POST /api/payments/{orderId}/cancel' },
  });

  const success = check(res, {
    'cancelPayment: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'cancelPayment: response time < 1000ms': (r) => r.timings.duration < 1000 });

  paymentCancelDuration.add(res.timings.duration);
  return success;
}

/**
 * Get All Payments (Manager/Master)
 */
export function testGetPayments(accessToken) {
  const res = http.get(buildUrl(endpoints.payment.getPayments), {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/payments' },
  });

  const success = check(res, {
    'getPayments: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getPayments: response time < 500ms': (r) => r.timings.duration < 500 });

  paymentListDuration.add(res.timings.duration);
  paymentListErrors.add(!success);

  return success ? JSON.parse(res.body) : null;
}

/**
 * Get Payment Detail
 */
export function testGetPayment(accessToken, paymentId) {
  const res = http.get(buildUrl(endpoints.payment.getPayment(paymentId)), {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/payments/{paymentId}' },
  });

  const success = check(res, {
    'getPayment: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getPayment: response time < 300ms': (r) => r.timings.duration < 300 });

  paymentDetailDuration.add(res.timings.duration);
  return success ? JSON.parse(res.body) : null;
}

/**
 * Get Cancelled Payments (Manager/Master)
 */
export function testGetCancelledPayments(accessToken) {
  const res = http.get(buildUrl(endpoints.payment.getCancelledPayments), {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/payments/cancel' },
  });

  const success = check(res, {
    'getCancelledPayments: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getCancelledPayments: response time < 500ms': (r) => r.timings.duration < 500 });

  return success ? JSON.parse(res.body) : null;
}

/**
 * Check Billing Key Exists
 */
export function testCheckBillingKeyExists(accessToken) {
  const res = http.get(buildUrl(endpoints.payment.checkBillingKeyExists), {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/payments/billing-key/exists' },
  });

  const success = check(res, {
    'checkBillingKeyExists: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'checkBillingKeyExists: response time < 200ms': (r) => r.timings.duration < 200 });

  billingKeyCheckDuration.add(res.timings.duration);
  return success ? JSON.parse(res.body) : null;
}

/**
 * Save Payment History
 */
export function testSavePaymentHistory(accessToken, historyData) {
  const payload = JSON.stringify(historyData || {
    orderId: env.testData.orderId,
    amount: 10000,
    paymentMethod: 'CARD',
  });

  const res = http.post(buildUrl(endpoints.payment.savePaymentHistory), payload, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'POST /api/payments/history' },
  });

  const success = check(res, {
    'savePaymentHistory: status is 200 or 201': (r) => r.status === 200 || r.status === 201,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'savePaymentHistory: response time < 500ms': (r) => r.timings.duration < 500 });

  return success;
}

/**
 * Customer Payment Flow
 */
export function customerPaymentFlow(accessToken) {
  group('Customer Payment Flow', () => {
    // 1. Check billing key exists
    testCheckBillingKeyExists(accessToken);
    thinkTime(0.5);

    // Note: Actual payment operations are typically done in real scenarios
    // testConfirmPayment(accessToken, orderId);
  });
}

/**
 * Admin Payment Management Flow
 */
export function adminPaymentManagementFlow(accessToken) {
  group('Admin Payment Management Flow', () => {
    // 1. Get all payments
    const payments = testGetPayments(accessToken);
    thinkTime(0.5);

    // 2. View payment detail
    if (payments && payments.content && payments.content.length > 0) {
      const paymentId = payments.content[0].id || payments.content[0].paymentId;
      testGetPayment(accessToken, paymentId);
      thinkTime(0.5);
    }

    // 3. Get cancelled payments
    testGetCancelledPayments(accessToken);
  });
}

export default customerPaymentFlow;
