// SPOT-STORE: Menu Management Scenarios
import http from 'k6/http';
import { check, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';
import { env, endpoints, buildUrl } from '../../config/index.js';
import { getAuthHeaders } from '../../lib/auth.js';
import { thinkTime } from '../../lib/helpers.js';

// Custom Metrics
const menuListDuration = new Trend('menu_list_duration');
const menuListErrors = new Rate('menu_list_errors');
const menuDetailDuration = new Trend('menu_detail_duration');
const menuDetailErrors = new Rate('menu_detail_errors');

/**
 * Get Menu List for a Store
 */
export function testGetMenus(accessToken, storeId) {
  const res = http.get(buildUrl(endpoints.store.getMenus(storeId)), {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/stores/{storeId}/menus' },
  });

  const success = check(res, {
    'getMenus: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getMenus: response time < 300ms': (r) => r.timings.duration < 300 });

  menuListDuration.add(res.timings.duration);
  menuListErrors.add(!success);

  return success ? JSON.parse(res.body) : null;
}

/**
 * Get Menu Detail
 */
export function testGetMenu(accessToken, storeId, menuId) {
  const res = http.get(buildUrl(endpoints.store.getMenu(storeId, menuId)), {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/stores/{storeId}/menus/{menuId}' },
  });

  const success = check(res, {
    'getMenu: status is 200': (r) => r.status === 200,
    'getMenu: has menu data': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.id !== undefined || body.name !== undefined;
      } catch {
        return false;
      }
    },
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'getMenu: response time < 200ms': (r) => r.timings.duration < 200 });

  menuDetailDuration.add(res.timings.duration);
  menuDetailErrors.add(!success);

  return success ? JSON.parse(res.body) : null;
}

/**
 * Create Menu (Owner)
 */
export function testCreateMenu(accessToken, storeId, menuData) {
  const payload = JSON.stringify(menuData || {
    name: `Test Menu ${Date.now()}`,
    price: 10000,
    description: 'Test menu description',
    isHidden: false,
  });

  const res = http.post(buildUrl(endpoints.store.createMenu(storeId)), payload, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'POST /api/stores/{storeId}/menus' },
  });

  const success = check(res, {
    'createMenu: status is 200 or 201': (r) => r.status === 200 || r.status === 201,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'createMenu: response time < 500ms': (r) => r.timings.duration < 500 });

  return success ? JSON.parse(res.body) : null;
}

/**
 * Update Menu (Owner)
 */
export function testUpdateMenu(accessToken, storeId, menuId, updateData) {
  const payload = JSON.stringify(updateData || {
    name: `Updated Menu ${Date.now()}`,
    price: 12000,
  });

  const res = http.patch(buildUrl(endpoints.store.updateMenu(storeId, menuId)), payload, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'PATCH /api/stores/{storeId}/menus/{menuId}' },
  });

  const success = check(res, {
    'updateMenu: status is 200': (r) => r.status === 200,
  });
  // 느림은 성공/실패와 분리: 에러율·반환값에 섞지 않음 (기준은 *_duration p95 threshold)
  check(res, { 'updateMenu: response time < 500ms': (r) => r.timings.duration < 500 });

  return success;
}

/**
 * Menu Browse Flow (Customer perspective)
 */
export function menuBrowseFlow(accessToken, storeId) {
  group('Menu Browse Flow', () => {
    const targetStoreId = storeId || env.testData.storeId;

    // 1. Get all menus for a store
    const menus = testGetMenus(accessToken, targetStoreId);
    thinkTime(1);

    // 2. View menu detail
    if (menus && menus.length > 0) {
      const menuId = menus[0].id || menus[0].menuId;
      testGetMenu(accessToken, targetStoreId, menuId);
    } else {
      // Fallback to test data
      testGetMenu(accessToken, targetStoreId, env.testData.menuId);
    }
  });
}

/**
 * Menu Management Flow (Owner perspective)
 */
export function menuManagementFlow(accessToken, storeId) {
  group('Menu Management Flow', () => {
    const targetStoreId = storeId || env.testData.storeId;

    // 1. List all menus
    const menus = testGetMenus(accessToken, targetStoreId);
    thinkTime(0.5);

    // 2. View menu detail
    if (menus && menus.length > 0) {
      const menuId = menus[0].id || menus[0].menuId;
      testGetMenu(accessToken, targetStoreId, menuId);
    }
  });
}

export default menuBrowseFlow;
