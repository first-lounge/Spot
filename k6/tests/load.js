import http from 'k6/http';
import { group } from 'k6';
import { env, endpoints, buildUrl, k6Thresholds } from '../config/index.js';
import { login, getAuthHeaders } from '../lib/auth.js';
import { randomItem, thinkTime } from '../lib/helpers.js';

// Scenarios Import
import { testGetStores, testGetStore } from '../scenarios/store/store.js';
import { testGetMenus, testGetMenu } from '../scenarios/store/menu.js';
import { testGetStoreReviews, testGetStoreReviewStats } from '../scenarios/store/review.js';
import { testGetMyOrders, testGetMyActiveOrders, testCreateOrderDynamic } from '../scenarios/order/customer.js';
import { testGetMyStoreOrders, testGetMyStoreActiveOrders } from '../scenarios/order/owner.js';

export const options = {
  scenarios: {
    customer_browse: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '3s', target: 3 },
        { duration: '3s', target: 3 },
        { duration: '3s', target: 0 },
      ],
      exec: 'customerBrowseScenario',
    },
    owner_manage: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '3s', target: 2 },
        { duration: '3s', target: 2 },
        { duration: '3s', target: 0 },
      ],
      exec: 'ownerManageScenario',
    },
  },
  // thresholds: {
  //   ...k6Thresholds.global,
  //   ...k6Thresholds.store,
  //   ...k6Thresholds.order,
  // },
};

export function setup() {
  const customerTokens = login('customer');
  const ownerTokens = login('owner');

  const storesRes = http.get(buildUrl(endpoints.store.getStores) + '?page=0&size=30', {
    headers: getAuthHeaders(customerTokens.accessToken),
  });

  let stores = [];
  if (storesRes.status === 200) {
    const data = JSON.parse(storesRes.body);
    stores = data.result || data.content || data;
  }

  return {
    customer: customerTokens,
    owner: ownerTokens,
    stores: stores,
  };
}

export function customerBrowseScenario(data) {
  const token = data.customer?.accessToken;
  if (!token) return;

  group('Customer Flow', () => {
    // 1. 상점 목록 보기
    testGetStores(token, { page: 0, size: 10 });
    thinkTime(1);

    // 2. [핵심] 주문 시도 (100% 확률로 테스트)
    const order = testCreateOrderDynamic(token, { validateIntegrity: true });
    if (order) {
      // 서버 응답이 { result: { id: "..." } } 형태인 경우를 대비해 처리
      const orderId = order.result ? (order.result.id || order.result.orderId) : (order.id || order.orderId);
      console.log(`[Order Success] ID: ${orderId}`);
    }

    // 3. 랜덤 상점 상세 및 메뉴 조회
    const selectedStore = randomItem(data.stores);
    if (selectedStore) {
      const storeId = selectedStore.id || selectedStore.storeId;
      testGetStore(token, storeId);

      const menusRes = testGetMenus(token, storeId);
      const menuList = menusRes.result || menusRes.content || [];

      if (menuList.length > 0) {
        const selectedMenu = randomItem(menuList);
        testGetMenu(token, storeId, selectedMenu.id);
      }

      testGetStoreReviewStats(storeId);
      testGetStoreReviews(storeId, { page: 0, size: 5 });
    }

    // 4. 내 주문 내역 확인
    testGetMyOrders(token, { page: 0, size: 5 });
    testGetMyActiveOrders(token);
    thinkTime(1);
  });
}

export function ownerManageScenario(data) {
  const token = data.owner?.accessToken;
  if (!token) return;

  group('Owner Flow', () => {
    testGetMyStoreActiveOrders(token);
    thinkTime(1);
    testGetMyStoreOrders(token, { page: 0, size: 10 });
    thinkTime(2);
  });
}