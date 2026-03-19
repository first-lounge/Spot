// Configuration Index
// 모든 설정을 통합하여 export

import { endpoints } from './endpoints.js';
import { thresholds, k6Thresholds, scenarios } from './thresholds.js';

// Environment Configuration
export const env = {
  baseUrl: __ENV.BASE_URL || 'http://www.spot:30080',

  // Test Users
  users: {
    customer: {
      username: __ENV.CUSTOMER_USERNAME || 'customer',
      password: __ENV.CUSTOMER_PASSWORD || 'customer',
    },
    owner: {
      username: __ENV.OWNER_USERNAME || 'owner',
      password: __ENV.OWNER_PASSWORD || 'owner',
    },
    chef: {
      username: __ENV.CHEF_USERNAME || 'chef',
      password: __ENV.CHEF_PASSWORD || 'chef',
    },
    manager: {
      username: __ENV.MANAGER_USERNAME || 'manager',
      password: __ENV.MANAGER_PASSWORD || 'manager',
    },
    master: {
      username: __ENV.MASTER_USERNAME || 'master',
      password: __ENV.MASTER_PASSWORD || 'master',
    },
  },

  // Test Data IDs
  testData: {
    storeId: __ENV.STORE_ID || '996b752c-ed89-45a6-aaa8-2f63d47f6224',
    menuId: __ENV.MENU_ID || 'a150bb83-388d-4a9a-92fe-c2523bf3d26a',
    orderId: __ENV.ORDER_ID || '',
    paymentId: __ENV.PAYMENT_ID || '',
    categoryId: __ENV.CATEGORY_ID || '',
    reviewId: __ENV.REVIEW_ID || '',
  },
};

// Re-export all configurations
export { endpoints, thresholds, k6Thresholds, scenarios };

// Helper function to build full URL
export function buildUrl(endpoint) {
  return `${env.baseUrl}${endpoint}`;
}
