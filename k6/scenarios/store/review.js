// SPOT-STORE: Review Management Scenarios
import http from 'k6/http';
import { check, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';
import { env, endpoints, buildUrl } from '../../config/index.js';
import { getAuthHeaders, getPublicHeaders } from '../../lib/auth.js';
import { thinkTime, buildQueryString } from '../../lib/helpers.js';

// Custom Metrics
const reviewListDuration = new Trend('review_list_duration');
const reviewListErrors = new Rate('review_list_errors');
const reviewStatsDuration = new Trend('review_stats_duration');
const reviewCreateDuration = new Trend('review_create_duration');

/**
 * Get Store Reviews (Public)
 */
export function testGetStoreReviews(storeId, params = {}) {
  const queryString = buildQueryString({
    page: params.page || 0,
    size: params.size || 10,
  });

  const res = http.get(buildUrl(endpoints.store.getStoreReviews(storeId)) + queryString, {
    headers: getPublicHeaders(),
    tags: { name: 'GET /api/reviews/stores/{storeId}' },
  });

  const success = check(res, {
    'getStoreReviews: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getStoreReviews: response time < 500ms': (r) => r.timings.duration < 500 });

  reviewListDuration.add(res.timings.duration);
  reviewListErrors.add(!success);

  return success ? JSON.parse(res.body) : null;
}

/**
 * Get Store Review Stats (Public)
 */
export function testGetStoreReviewStats(storeId) {
  const res = http.get(buildUrl(endpoints.store.getStoreReviewStats(storeId)), {
    headers: getPublicHeaders(),
    tags: { name: 'GET /api/reviews/stores/{storeId}/stats' },
  });

  const success = check(res, {
    'getReviewStats: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getReviewStats: response time < 300ms': (r) => r.timings.duration < 300 });

  reviewStatsDuration.add(res.timings.duration);
  return success ? JSON.parse(res.body) : null;
}

/**
 * Create Review (Customer)
 */
export function testCreateReview(accessToken, reviewData) {
  const payload = JSON.stringify(reviewData || {
    storeId: env.testData.storeId,
    orderId: env.testData.orderId,
    rating: 5,
    content: 'Great food and service!',
  });

  const res = http.post(buildUrl(endpoints.store.createReview), payload, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'POST /api/reviews' },
  });

  const success = check(res, {
    'createReview: status is 200 or 201': (r) => r.status === 200 || r.status === 201,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'createReview: response time < 500ms': (r) => r.timings.duration < 500 });

  reviewCreateDuration.add(res.timings.duration);
  return success ? JSON.parse(res.body) : null;
}

/**
 * Update Review (Customer)
 */
export function testUpdateReview(accessToken, reviewId, updateData) {
  const payload = JSON.stringify(updateData || {
    rating: 4,
    content: 'Updated review content',
  });

  const res = http.patch(buildUrl(endpoints.store.updateReview(reviewId)), payload, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'PATCH /api/reviews/{reviewId}' },
  });

  const success = check(res, {
    'updateReview: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'updateReview: response time < 500ms': (r) => r.timings.duration < 500 });

  return success;
}

/**
 * Review Browse Flow
 */
export function reviewBrowseFlow(storeId) {
  group('Review Browse Flow', () => {
    const targetStoreId = storeId || env.testData.storeId;

    // 1. Get review stats
    testGetStoreReviewStats(targetStoreId);
    thinkTime(0.5);

    // 2. Get reviews
    testGetStoreReviews(targetStoreId, { page: 0, size: 10 });
  });
}

export default reviewBrowseFlow;
