/**
 * Order-Only Load Test
 * 주문 생성(POST /api/orders) 전용 k6 테스트
 *
 * 사용법:
 *   smoke  : k6 run -e TEST_TYPE=smoke  order-only.js
 *   load   : k6 run -e TEST_TYPE=load   order-only.js
 *   stress : k6 run -e TEST_TYPE=stress order-only.js
 *   spike  : k6 run -e TEST_TYPE=spike  order-only.js
 *
 * 추가 환경변수 (선택):
 *   -e BASE_URL=http://your-server:8080
 *   -e CUSTOMER_USERNAME=customer
 *   -e CUSTOMER_PASSWORD=customer
 *   -e STORE_ID=<uuid>
 *   -e MENU_ID=<uuid>
 */

import http from 'k6/http';
import { check, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';

import { env, endpoints, buildUrl } from '../config/index.js';
import { login, getAuthHeaders } from '../lib/auth.js';
import { thinkTime, randomItem, buildQueryString } from '../lib/helpers.js';

// ===================== Custom Metrics =====================
const orderCreateDuration = new Trend('order_create_duration');
const orderCreateErrors   = new Rate('order_create_errors');
const storeListDuration   = new Trend('store_list_duration');
const menuListDuration    = new Trend('menu_list_duration');
const priceIntegrityErrors = new Rate('price_integrity_errors');

// ===================== Scenario Profiles =====================
const TEST_TYPE = __ENV.TEST_TYPE || 'smoke';

const profiles = {
    /**
     * Smoke: 최소 VU로 기본 동작 확인
     * 목적: 스크립트 오류 없는지, 주문 생성이 정상적으로 되는지 빠르게 검증
     */
    smoke: {
        stages: [
            { duration: '10s', target: 1 },
            { duration: '20s', target: 1 },
            { duration: '10s', target: 0 },
        ],
        thresholds: {
            'order_create_errors':   ['rate<0.01'],       // 오류율 1% 미만
            'order_create_duration': ['p(95)<2000'],      // 95%ile 2초 이내
        },
    },

    /**
     * Load: 일반 트래픽 수준의 부하 테스트
     * 목적: 평상시 예상 부하에서 안정적으로 동작하는지 확인
     */
    load: {
        stages: [
            { duration: '1m',  target: 10 },   // 램프업
            { duration: '3m',  target: 10 },   // 유지
            { duration: '1m',  target: 0  },   // 램프다운
        ],
        thresholds: {
            'order_create_errors':   ['rate<0.05'],                       // 오류율 5% 미만
            'order_create_duration': ['p(95)<1500', 'p(99)<3000'],       // 95%ile 1.5초, 99%ile 3초 이내
        },
    },

    /**
     * Stress: 한계점 탐색
     * 목적: 시스템이 몇 VU까지 버티는지, 언제부터 오류가 급증하는지 파악
     */
    stress: {
        stages: [
            { duration: '1m',  target: 20  },
            { duration: '1m',  target: 40  },
            { duration: '1m',  target: 60  },
            { duration: '1m',  target: 80  },
            { duration: '1m',  target: 100 },
            { duration: '2m',  target: 100 },  // 최대 부하 유지
            { duration: '1m',  target: 0   },  // 복구 확인
        ],
        thresholds: {
            'order_create_errors':   ['rate<0.1'],        // 오류율 10% 미만
            'order_create_duration': ['p(95)<5000'],      // 95%ile 5초 이내
        },
    },

    /**
     * Spike: 급격한 트래픽 폭증 시뮬레이션
     * 목적: 갑작스러운 대량 요청(이벤트, 점심시간 등)에 시스템이 버티는지 확인
     */
    spike: {
        stages: [
            { duration: '10s', target: 5   },  // 평상시
            { duration: '10s', target: 100 },  // 스파이크 급상승
            { duration: '30s', target: 100 },  // 스파이크 유지
            { duration: '10s', target: 5   },  // 급하강
            { duration: '30s', target: 5   },  // 복구 확인
            { duration: '10s', target: 0   },
        ],
        thresholds: {
            'order_create_errors':   ['rate<0.15'],       // 스파이크 구간 오류율 15% 허용
            'order_create_duration': ['p(95)<10000'],     // 95%ile 10초 이내
        },
    },
};

const selectedProfile = profiles[TEST_TYPE];
if (!selectedProfile) {
    throw new Error(`Unknown TEST_TYPE: "${TEST_TYPE}". Use one of: smoke, load, stress, spike`);
}

// ===================== k6 Options =====================
export const options = {
    scenarios: {
        order_test: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: selectedProfile.stages,
            exec: 'orderScenario',
        },
    },
    thresholds: selectedProfile.thresholds,
};

// ===================== Setup =====================
export function setup() {
    console.log(`\n========================================`);
    console.log(`  TEST_TYPE : ${TEST_TYPE.toUpperCase()}`);
    console.log(`  BASE_URL  : ${env.baseUrl}`);
    console.log(`========================================\n`);

    const customerTokens = login('customer');
    if (!customerTokens.accessToken) {
        throw new Error('Customer login failed. Check credentials and BASE_URL.');
    }

    // 상점 목록 사전 로드 (setup에서 1번만 호출)
    const storesRes = http.get(
        buildUrl(endpoints.store.getStores) + '?page=0&size=50',
        { headers: getAuthHeaders(customerTokens.accessToken) }
    );

    let stores = [];
    if (storesRes.status === 200) {
        const data = JSON.parse(storesRes.body);
        const raw = data.result || data.content || data;
        // APPROVED 상태만 필터링
        stores = (Array.isArray(raw) ? raw : []).filter(
            (s) => (s.status || s.storeStatus) === 'APPROVED'
        );
    }

    console.log(`Loaded ${stores.length} APPROVED store(s) for test.`);

    return {
        accessToken: customerTokens.accessToken,
        stores,
    };
}

// ===================== Main Scenario =====================
export function orderScenario(data) {
    const { accessToken, stores } = data;
    if (!accessToken) return;

    group('Order Create Flow', () => {
        // 1. 상점 선택
        const selectedStore = pickStore(accessToken, stores);
        if (!selectedStore) return;

        const storeId = selectedStore.id || selectedStore.storeId;

        // 2. 메뉴 선택
        const selectedMenu = pickMenu(accessToken, storeId);
        if (!selectedMenu) return;

        const menuId    = selectedMenu.id    || selectedMenu.menuId;
        const menuPrice = selectedMenu.price || 0;
        const quantity  = Math.floor(Math.random() * 3) + 1;

        thinkTime(1); // 사용자가 메뉴 고르는 시간

        // 3. 주문 생성
        const orderResult = createOrder(accessToken, { storeId, menuId, quantity });

        // 4. 가격 정합성 검증
        if (orderResult) {
            const expectedTotal = menuPrice * quantity;
            const actualTotal   = orderResult.totalPrice || orderResult.totalAmount || 0;

            if (expectedTotal > 0 && actualTotal > 0 && expectedTotal !== actualTotal) {
                console.error(`[PRICE MISMATCH] expected=${expectedTotal}, actual=${actualTotal}`);
                priceIntegrityErrors.add(1);
            } else {
                priceIntegrityErrors.add(0);
            }

            const orderId = (orderResult.result?.id || orderResult.result?.orderId || orderResult.id || orderResult.orderId);
            console.log(`[Order OK] id=${orderId}, store=${storeId}, menu=${menuId}, qty=${quantity}`);
        }

        thinkTime(1);
    });
}

// ===================== Helper Functions =====================

/**
 * setup()에서 받아온 stores 목록을 우선 사용.
 * 비어있으면 실시간으로 GET /stores 재조회.
 */
function pickStore(accessToken, cachedStores) {
    if (cachedStores && cachedStores.length > 0) {
        return randomItem(cachedStores);
    }

    // fallback: 실시간 조회
    const res = http.get(
        buildUrl(endpoints.store.getStores) + '?page=0&size=50',
        {
            headers: getAuthHeaders(accessToken),
            tags: { name: 'GET /stores (fallback)' },
        }
    );

    storeListDuration.add(res.timings.duration);

    if (res.status !== 200) {
        console.warn(`Store list fetch failed: ${res.status}`);
        return null;
    }

    const data = JSON.parse(res.body);
    const raw  = data.result || data.content || (Array.isArray(data) ? data : []);
    const open = raw.filter((s) => (s.status || s.storeStatus) === 'APPROVED');

    if (open.length === 0) {
        console.warn('No APPROVED stores found.');
        return null;
    }

    return randomItem(open);
}

/**
 * storeId에 속한 메뉴 목록에서 랜덤 메뉴 반환
 */
function pickMenu(accessToken, storeId) {
    const url = buildUrl(endpoints.store.getMenus(storeId));

    const res = http.get(url, {
        headers: getAuthHeaders(accessToken),
        tags: { name: 'GET /menus' },
    });

    menuListDuration.add(res.timings.duration);

    if (res.status !== 200) {
        console.warn(`Menu list fetch failed for store ${storeId}: ${res.status}`);
        return null;
    }

    const data     = JSON.parse(res.body);
    const menuList = data.result || data.content || (Array.isArray(data) ? data : []);

    if (menuList.length === 0) {
        console.warn(`No menus for store ${storeId}`);
        return null;
    }

    return randomItem(menuList);
}

/**
 * 주문 생성 POST 요청
 */
function createOrder(accessToken, { storeId, menuId, quantity }) {
    const now        = new Date();
    const pickupDate = new Date(now.getTime() + 30 * 60000); // 30분 뒤
    const pad        = (n) => String(n).padStart(2, '0');
    const pickupTime = [
        `${pickupDate.getFullYear()}-${pad(pickupDate.getMonth() + 1)}-${pad(pickupDate.getDate())}`,
        `T`,
        `${pad(pickupDate.getHours())}:${pad(pickupDate.getMinutes())}:${pad(pickupDate.getSeconds())}`,
    ].join('');

    const payload = JSON.stringify({
        storeId,
        orderItems: [{ menuId, quantity, options: [] }],
        pickupTime,
        needDisposables: false,
        request: `k6 ${TEST_TYPE} test order`,
    });

    const res = http.post(buildUrl(endpoints.order.createOrder), payload, {
        headers: getAuthHeaders(accessToken),
        tags: { name: 'POST /orders' },
    });

    const success = check(res, {
        'createOrder: status 200 or 201': (r) => r.status === 200 || r.status === 201,
    });

    orderCreateDuration.add(res.timings.duration);
    orderCreateErrors.add(!success);

    if (!success) {
        console.error(`[Order FAIL] ${res.status} - ${res.body?.substring(0, 300)}`);
        return null;
    }

    return JSON.parse(res.body);
}