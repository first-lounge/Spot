// SPOT-STORE: Category Management Scenarios
import http from 'k6/http';
import { check, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';
import { endpoints, buildUrl } from '../../config/index.js';
import { getAuthHeaders, getPublicHeaders } from '../../lib/auth.js';
import { thinkTime } from '../../lib/helpers.js';

// Custom Metrics
const categoryListDuration = new Trend('category_list_duration');
const categoryListErrors = new Rate('category_list_errors');
const categoryStoresDuration = new Trend('category_stores_duration');

/**
 * Get All Categories (Public)
 */
export function testGetCategories(accessToken = null) {
  const headers = accessToken ? getAuthHeaders(accessToken) : getPublicHeaders();

  const res = http.get(buildUrl(endpoints.store.getCategories), {
    headers,
    tags: { name: 'GET /api/categories' },
  });

  const success = check(res, {
    'getCategories: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getCategories: response time < 200ms': (r) => r.timings.duration < 200 });

  categoryListDuration.add(res.timings.duration);
  categoryListErrors.add(!success);

  return success ? JSON.parse(res.body) : null;
}

/**
 * Get Stores by Category (Public)
 */
export function testGetStoresByCategory(categoryName, accessToken = null) {
  const headers = accessToken ? getAuthHeaders(accessToken) : getPublicHeaders();

  const res = http.get(buildUrl(endpoints.store.getStoresByCategory(categoryName)), {
    headers,
    tags: { name: 'GET /api/categories/{categoryName}/stores' },
  });

  const success = check(res, {
    'getStoresByCategory: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getStoresByCategory: response time < 500ms': (r) => r.timings.duration < 500 });

  categoryStoresDuration.add(res.timings.duration);
  return success ? JSON.parse(res.body) : null;
}

/**
 * Create Category (Admin)
 */
export function testCreateCategory(accessToken, categoryData) {
  const payload = JSON.stringify(categoryData || {
    name: `TestCategory_${Date.now()}`,
  });

  const res = http.post(buildUrl(endpoints.store.createCategory), payload, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'POST /api/categories' },
  });

  const success = check(res, {
    'createCategory: status is 200 or 201': (r) => r.status === 200 || r.status === 201,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'createCategory: response time < 500ms': (r) => r.timings.duration < 500 });

  return success ? JSON.parse(res.body) : null;
}

/**
 * Category Browse Flow
 */
export function categoryBrowseFlow(accessToken = null) {
  group('Category Browse Flow', () => {
    // 1. Get all categories
    const categories = testGetCategories(accessToken);
    thinkTime(0.5);

    // 2. Get stores by category
    if (categories && categories.length > 0) {
      const categoryName = categories[0].name;
      testGetStoresByCategory(categoryName, accessToken);
    }
  });
}

export default categoryBrowseFlow;
