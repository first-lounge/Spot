// SPOT-STORE: Store Management Scenarios
import http from 'k6/http';
import { check, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';
import { env, endpoints, buildUrl } from '../../config/index.js';
import { getAuthHeaders } from '../../lib/auth.js';
import { thinkTime, buildQueryString } from '../../lib/helpers.js';

// Custom Metrics
const storeListDuration = new Trend('store_list_duration');
const storeListErrors = new Rate('store_list_errors');
const storeDetailDuration = new Trend('store_detail_duration');
const storeDetailErrors = new Rate('store_detail_errors');
const storeSearchDuration = new Trend('store_search_duration');
const storeSearchErrors = new Rate('store_search_errors');
const myStoreDuration = new Trend('store_my_duration');

/**
 * Get Store List
 */
export function testGetStores(accessToken, params = {}) {
  const queryString = buildQueryString({
    page: params.page || 0,
    size: params.size || 50,
  });

  const res = http.get(buildUrl(endpoints.store.getStores) + queryString, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/stores' },
  });

  const success = check(res, {
    'getStores: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getStores: response time < 500ms': (r) => r.timings.duration < 500 });

  storeListDuration.add(res.timings.duration);
  storeListErrors.add(!success);

  return success ? JSON.parse(res.body) : null;
}

/**
 * Get Store Detail
 */
export function testGetStore(accessToken, storeId) {
  const res = http.get(buildUrl(endpoints.store.getStore(storeId)), {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/stores/{storeId}' },
  });

  const success = check(res, {
    'getStore: status is 200': (r) => r.status === 200,
    'getStore: has store data': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.id !== undefined || body.storeId !== undefined || body.name !== undefined;
      } catch {
        return false;
      }
    },
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getStore: response time < 300ms': (r) => r.timings.duration < 300 });

  storeDetailDuration.add(res.timings.duration);
  storeDetailErrors.add(!success);

  return success ? JSON.parse(res.body) : null;
}

/**
 * Search Stores
 */
export function testSearchStores(accessToken, keyword, params = {}) {
  const queryString = buildQueryString({
    keyword: keyword,
    page: params.page || 0,
    size: params.size || 50,
  });

  const res = http.get(buildUrl(endpoints.store.searchStores) + queryString, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/stores/search' },
  });

  const success = check(res, {
    'searchStores: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'searchStores: response time < 500ms': (r) => r.timings.duration < 500 });

  storeSearchDuration.add(res.timings.duration);
  storeSearchErrors.add(!success);

  return success ? JSON.parse(res.body) : null;
}

/**
 * Get My Store (Owner/Chef)
 */
export function testGetMyStore(accessToken) {
  const res = http.get(buildUrl(endpoints.store.getMyStore), {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/stores/my' },
  });

  const success = check(res, {
    'getMyStore: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getMyStore: response time < 300ms': (r) => r.timings.duration < 300 });

  myStoreDuration.add(res.timings.duration);
  return success ? JSON.parse(res.body) : null;
}

/**
 * Create Store (Owner)
 */
export function testCreateStore(accessToken, storeData) {
  const payload = JSON.stringify(storeData || {
    name: `Test Store ${Date.now()}`,
    address: 'Test Address',
    phone: '02-1234-5678',
    description: 'Test store description',
    categoryId: env.testData.categoryId,
  });

  const res = http.post(buildUrl(endpoints.store.createStore), payload, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'POST /api/stores' },
  });

  const success = check(res, {
    'createStore: status is 200 or 201': (r) => r.status === 200 || r.status === 201,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'createStore: response time < 1000ms': (r) => r.timings.duration < 1000 });

  return success ? JSON.parse(res.body) : null;
}

/**
 * Store Browse Flow (Customer perspective)
 */
export function storeBrowseFlow(accessToken) {
  group('Store Browse Flow', () => {
    // 1. Get all stores
    const stores = testGetStores(accessToken, { page: 0, size: 10 });
    thinkTime(1);

    // 2. View store detail
    if (stores && stores.content && stores.content.length > 0) {
      const storeId = stores.content[0].id || stores.content[0].storeId;
      testGetStore(accessToken, storeId);
      thinkTime(0.5);
    } else {
      // Fallback to test data
      testGetStore(accessToken, env.testData.storeId);
    }

    // 3. Search stores
    testSearchStores(accessToken, 'test', { page: 0, size: 10 });
  });
}

/**
 * Store Management Flow (Owner perspective)
 */
export function storeManagementFlow(accessToken) {
  group('Store Management Flow', () => {
    // 1. Get my store
    const myStore = testGetMyStore(accessToken);
    thinkTime(0.5);

    // 2. View store details
    if (myStore) {
      const storeId = myStore.id || myStore.storeId;
      testGetStore(accessToken, storeId);
    }
  });
}

export default storeBrowseFlow;
