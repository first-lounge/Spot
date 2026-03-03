// SPOT-ORDER: Customer Order Scenarios
import http from 'k6/http';
import { check, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';
import { env, endpoints, buildUrl } from '../../config/index.js';
import { getAuthHeaders } from '../../lib/auth.js';
import { thinkTime, buildQueryString, randomItem } from '../../lib/helpers.js';
import { testGetStores } from '../store/store.js';
import { testGetMenus } from '../store/menu.js';

// Custom Metrics
const orderCreateErrors = new Rate('order_create_errors');
const orderListDuration = new Trend('order_list_duration');
const orderListErrors = new Rate('order_list_errors');
const orderActiveDuration = new Trend('order_active_duration');
const orderCancelDuration = new Trend('order_cancel_duration');
const categoryListDuration = new Trend('category_list_duration');
const storeListDuration = new Trend('store_list_duration');
const orderCreateDuration = new Trend('order_create_duration');

// Data Integrity Metrics
const priceIntegrityErrors = new Rate('price_integrity_errors');
const orderReflectionErrors = new Rate('order_reflection_errors');
const storeStatusErrors = new Rate('store_status_errors');

/**
 * Create Order (Customer)
 */
export function testCreateOrder(accessToken, orderData) {
  const now = new Date();
  const pickupDate = new Date(now.getTime() + 30 * 60000); // 30분 뒤

  // Java LocalDateTime이 가장 완벽하게 인식하는 ISO 8601 로컬 형식 (T 포함, Z 제외)
  const pad = (n) => n < 10 ? '0' + n : n;
  const formattedPickupTime = `${pickupDate.getFullYear()}-${pad(pickupDate.getMonth() + 1)}-${pad(pickupDate.getDate())}T${pad(pickupDate.getHours())}:${pad(pickupDate.getMinutes())}:${pad(pickupDate.getSeconds())}`;

  // 핵심: 외부에서 들어온 orderData가 있더라도 pickupTime과 request는 여기서 강제로 덮어씌웁니다.
  const finalPayload = {
    storeId: orderData.storeId || env.testData.storeId,
    orderItems: orderData.orderItems || [
      {
        menuId: env.testData.menuId,
        quantity: 1,
        options: []
      },
    ],
    pickupTime: formattedPickupTime, // 강제 주입
    needDisposables: orderData.needDisposables !== undefined ? orderData.needDisposables : false,
    request: orderData.request || orderData.memo || 'k6 load test order',
  };

  const res = http.post(buildUrl(endpoints.order.createOrder), JSON.stringify(finalPayload), {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'POST /api/orders' },
  });

  const success = check(res, {
    'createOrder: status is 200 or 201': (r) => r.status === 200 || r.status === 201,
  });

  if (!success) {
    console.error(`Order Create Failed: ${res.status} - ${res.body}`);
  }

  orderCreateDuration.add(res.timings.duration);
  orderCreateErrors.add(!success);

  return success ? JSON.parse(res.body) : null;
}

/**
 * Get My Orders (Customer)
 */
export function testGetMyOrders(accessToken, params = {}) {
  const queryString = buildQueryString({
    storeId: params.storeId,
    date: params.date,
    status: params.status,
    page: params.page || 0,
    size: params.size || 10,
    sortBy: params.sortBy || 'createdAt',
    direction: params.direction || 'DESC',
  });

  const res = http.get(buildUrl(endpoints.order.getMyOrders) + queryString, {
    headers: getAuthHeaders(accessToken),
    tags: { name: 'GET /api/orders/my' },
  });

  const success = check(res, {
    'getMyOrders: status is 200': (r) => r.status === 200,
    'getMyOrders: response time < 500ms': (r) => r.timings.duration < 500,
  });

  orderListDuration.add(res.timings.duration);
  orderListErrors.add(!success);

  // 결과값이 .result에 들어있을 경우와 .content에 들어있을 경우 모두 대응
  if (success) {
    const body = JSON.parse(res.body);
    return body.result || body.content || body;
  }
  return null;
}

/**
 * Create Order with Dynamic Selection
 */
export function testCreateOrderDynamic(accessToken, options = {}) {
  const { validateIntegrity = true } = options;

  // 1. Store 목록 조회 (result와 content 모두 대응)
  const storesRes = testGetStores(accessToken, { page: 0, size: 50 });
  const storeList = storesRes.result || storesRes.content || (Array.isArray(storesRes) ? storesRes : []);

  if (storeList.length === 0) {
    console.warn('No stores available');
    return null;
  }

  // 2. APPROVED 상태인 store 필터링
  const openStores = storeList.filter((store) => {
    const status = store.status || store.storeStatus;
    return status === 'APPROVED';
  });

  if (openStores.length === 0) {
    storeStatusErrors.add(1);
    return null;
  }
  storeStatusErrors.add(0);

  // 3. 랜덤 상점 선택
  const selectedStore = randomItem(openStores);
  const storeId = selectedStore.id || selectedStore.storeId;

  // 4. 메뉴 목록 조회 (.result 우선 참조)
  const menusRes = testGetMenus(accessToken, storeId);
  const menuList = menusRes.result || menusRes.content || (Array.isArray(menusRes) ? menusRes : []);

  if (!menuList || menuList.length === 0) {
    console.warn(`No menus available for store ${storeId}`);
    return null;
  }

  // 5. 랜덤 메뉴 선택
  const selectedMenu = randomItem(menuList);
  const menuId = selectedMenu.id || selectedMenu.menuId;
  const menuPrice = selectedMenu.price || 0;
  const quantity = Math.floor(Math.random() * 3) + 1;
  const expectedTotal = menuPrice * quantity;

  // 6. 주문 데이터 생성
  const orderData = {
    storeId: storeId,
    orderItems: [
      {
        menuId: menuId,
        quantity: quantity,
        options: [],
      },
    ],
    memo: `Dynamic order from k6 - Store: ${selectedStore.name || storeId}`,
  };

  const orderResult = testCreateOrder(accessToken, orderData);

  // 7. 정합성 검증
  if (validateIntegrity && orderResult) {
    const orderTotal = orderResult.totalPrice || orderResult.totalAmount || 0;
    if (orderTotal > 0 && expectedTotal > 0 && orderTotal !== expectedTotal) {
      console.error(`[PRICE INTEGRITY ERROR] Expected: ${expectedTotal}, Got: ${orderTotal}`);
      priceIntegrityErrors.add(1);
    } else {
      priceIntegrityErrors.add(0);
    }
  }

  return orderResult;
}

// 나머지 Flow 함수들은 동일...
export function testGetMyActiveOrders(accessToken) { /* ... 기존과 동일 ... */ }
export function customerOrderFlow(accessToken, options = {}) { /* ... 기존과 동일 ... */ }
export default customerOrderFlow;