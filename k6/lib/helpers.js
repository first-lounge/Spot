// Common Helper Functions
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// ==================== Custom Metrics Factory ====================

/**
 * Create custom metrics for a scenario
 * @param {string} prefix - metric prefix (e.g., 'store_list')
 * @returns {object} - { duration, errors, success }
 */
export function createMetrics(prefix) {
  return {
    duration: new Trend(`${prefix}_duration`),
    errors: new Rate(`${prefix}_errors`),
    success: new Counter(`${prefix}_success`),
    failure: new Counter(`${prefix}_failure`),
  };
}

// ==================== Response Checkers ====================

/**
 * Check response status and timing
 * @param {object} res - k6 response object
 * @param {string} name - check name prefix
 * @param {number} expectedStatus - expected HTTP status (default: 200)
 * @param {number} maxDuration - max response time in ms (default: 500)
 * @returns {boolean} - status check passed (응답시간은 성공 여부에 포함하지 않음)
 */
export function checkResponse(res, name, expectedStatus = 200, maxDuration = 500) {
  // 느림은 성공/실패와 분리: 기록만 하고 반환값에는 섞지 않음
  check(res, { [`${name}: response time < ${maxDuration}ms`]: (r) => r.timings.duration < maxDuration });
  return check(res, {
    [`${name}: status is ${expectedStatus}`]: (r) => r.status === expectedStatus,
  });
}

/**
 * Check response with body validation
 * @param {object} res - k6 response object
 * @param {string} name - check name prefix
 * @param {function} bodyValidator - function to validate body
 * @returns {boolean} - all checks passed
 */
export function checkResponseWithBody(res, name, bodyValidator) {
  return check(res, {
    [`${name}: status is 200`]: (r) => r.status === 200,
    [`${name}: body is valid`]: (r) => {
      try {
        const body = JSON.parse(r.body);
        return bodyValidator(body);
      } catch {
        return false;
      }
    },
  });
}

// ==================== Request Helpers ====================

/**
 * Parse JSON response safely
 * @param {object} res - k6 response object
 * @returns {object|null} - parsed JSON or null
 */
export function parseJson(res) {
  try {
    return JSON.parse(res.body);
  } catch {
    console.error(`Failed to parse JSON: ${res.body}`);
    return null;
  }
}

/**
 * Build query string from params object
 * @param {object} params - query parameters
 * @returns {string} - query string (e.g., '?page=0&size=10')
 */
export function buildQueryString(params) {
  const query = Object.entries(params)
    .filter(([_, v]) => v !== undefined && v !== null)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join('&');
  return query ? `?${query}` : '';
}

// ==================== Sleep Helpers ====================

/**
 * Random sleep between min and max seconds
 * @param {number} min - minimum seconds
 * @param {number} max - maximum seconds
 */
export function randomSleep(min = 0.5, max = 2) {
  const duration = Math.random() * (max - min) + min;
  sleep(duration);
}

/**
 * Think time - simulates user thinking
 * @param {number} seconds - base think time
 */
export function thinkTime(seconds = 1) {
  randomSleep(seconds * 0.5, seconds * 1.5);
}

// ==================== Data Generators ====================

/**
 * Generate random string
 * @param {number} length - string length
 * @returns {string}
 */
export function randomString(length = 8) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/**
 * Generate random email
 * @returns {string}
 */
export function randomEmail() {
  return `test_${randomString(8)}@example.com`;
}

/**
 * Generate random phone number
 * @returns {string}
 */
export function randomPhone() {
  return `010${Math.floor(Math.random() * 90000000 + 10000000)}`;
}

/**
 * Pick random item from array
 * @param {array} arr
 * @returns {any}
 */
export function randomItem(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

// ==================== Logging Helpers ====================

/**
 * Log request details
 * @param {string} method - HTTP method
 * @param {string} url - request URL
 * @param {object} res - response object
 */
export function logRequest(method, url, res) {
  console.log(`[${method}] ${url} -> ${res.status} (${res.timings.duration.toFixed(0)}ms)`);
}

/**
 * Log error details
 * @param {string} name - operation name
 * @param {object} res - response object
 */
export function logError(name, res) {
  console.error(`[ERROR] ${name}: Status ${res.status}, Body: ${res.body?.substring(0, 200)}`);
}
