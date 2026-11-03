/**
 * Store Blue/Green Test
 * B/G 배포 중 store API(매장 상세·메뉴 목록·메뉴 상세)가 끊기는지 확인
 * 사용법: ./run.sh store-bg
 */

import http from 'k6/http';
import { check, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';

import { env, endpoints, buildUrl } from '../config/index.js';
import { login, getAuthHeaders } from '../lib/auth.js';
import { thinkTime, randomItem } from '../lib/helpers.js';

// 성공/실패는 status 200 여부만으로 판정 (응답시간은 따로 기록)
const storeErrors   = new Rate('store_bg_errors');
const storeDuration = new Trend('store_bg_duration');

// ===================== k6 Options =====================
export const options = {
    scenarios: {
        store_bg: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '1m',  target: 10 },   // 램프업
                { duration: '10m', target: 10 },   // 유지
                { duration: '1m',  target: 0  },   // 램프다운
            ],
            exec: 'storeScenario',
        },
    },
    thresholds: {
        store_bg_errors: ['rate==0.0'],   // 실패 0건이어야 통과
    },
};

// ===================== Setup =====================
export function setup() {
    console.log(`  BASE_URL  : ${env.baseUrl}`);

    const { accessToken } = login('customer');
    if (!accessToken) {
        throw new Error('Customer login failed. Check credentials and BASE_URL.');
    }

    // 상점 목록 사전 로드 (setup에서 1번만 호출)
    const storesRes = http.get(
        buildUrl(endpoints.store.getStores) + '?page=0&size=50',
        { headers: getAuthHeaders(accessToken) }
    );

    const stores = storesRes.status === 200 ? (JSON.parse(storesRes.body).content || []).filter((s) => (s.status || s.storeStatus) === 'APPROVED') : [];

    if (stores.length === 0) {
        throw new Error(`No APPROVED stores (status ${storesRes.status})`);
    }

    console.log(`Loaded ${stores.length} APPROVED store(s) for test.`);
    return { accessToken, stores };
}

// ===================== Main Scenario =====================
function get(url, accessToken, name) {
    const res = http.get(url, {
        headers: getAuthHeaders(accessToken),
        tags: { name },
        timeout: '5s',
    });

    const ok = check(res, { [`${name}: status 200`]: (r) => r.status === 200 });
    storeErrors.add(!ok);
    storeDuration.add(res.timings.duration);

    if (!ok) console.warn(`[FAIL] ${name} → ${res.status}`);
    return ok ? JSON.parse(res.body) : null;
}


export function storeScenario({ accessToken, stores }) {
    group('Store Browse Flow', () => {
        const storeId = randomItem(stores).id;
        
        // 1. 매장 상세
        get(buildUrl(endpoints.store.getStore(storeId)), accessToken, 'GET /stores/{id}');

        // 2. 메뉴 목록 (ApiResponse → result 배열)
        const menus    = get(buildUrl(endpoints.store.getMenus(storeId)), accessToken, 'GET /menus');
        const menuList = (menus && menus.result) || [];

        // 3. 메뉴 상세 (메뉴가 있을 때만)
        if (menuList.length > 0) {
            const menuId = randomItem(menuList).id;
            get(buildUrl(endpoints.store.getMenu(storeId, menuId)), accessToken, 'GET /menus/{id}');
        }

        thinkTime(1); // 사용자가 메뉴 고르는 시간
    });
}