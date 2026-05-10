// ============================================================
// k6 Smoke Test — NexaCommerce
// Quick validation that all critical paths work
// Run before every production deployment
// ============================================================

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('error_rate');

export const options = {
  vus: 5,
  duration: '2m',
  thresholds: {
    'error_rate': ['rate<0.01'],
    'http_req_duration': ['p(99)<1000'],
    'http_req_failed': ['rate<0.01'],
    'checks': ['rate>0.99'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'https://api.nexacommerce.com';
const HEADERS  = { 'Content-Type': 'application/json', 'Accept': 'application/json' };

export default function () {
  // ── Health Checks ────────────────────────────────────────
  group('Health Checks', () => {
    const res = http.get(`${BASE_URL}/health`, { headers: HEADERS });
    const ok = check(res, {
      'health: status 200': (r) => r.status === 200,
      'health: status is UP': (r) => r.json('status') === 'UP',
    });
    errorRate.add(!ok);
  });

  sleep(0.5);

  // ── Auth Service ─────────────────────────────────────────
  group('Auth Service', () => {
    const res = http.get(`${BASE_URL}/auth/health`, { headers: HEADERS });
    const ok = check(res, {
      'auth: health 200': (r) => r.status === 200,
    });
    errorRate.add(!ok);
  });

  sleep(0.5);

  // ── Product Service ──────────────────────────────────────
  group('Product Service', () => {
    const res = http.get(`${BASE_URL}/products?limit=5`, { headers: HEADERS });
    const ok = check(res, {
      'products: status 200': (r) => r.status === 200,
      'products: returns array': (r) => Array.isArray(r.json('items')),
      'products: has items': (r) => r.json('items').length > 0,
    });
    errorRate.add(!ok);
  });

  sleep(0.5);

  // ── Search Service ───────────────────────────────────────
  group('Search Service', () => {
    const res = http.get(`${BASE_URL}/search?q=laptop&limit=5`, { headers: HEADERS });
    const ok = check(res, {
      'search: status 200': (r) => r.status === 200,
      'search: has results': (r) => r.json('total') !== undefined,
    });
    errorRate.add(!ok);
  });

  sleep(0.5);

  // ── Cart Service (unauthenticated) ───────────────────────
  group('Cart Service Health', () => {
    const res = http.get(`${BASE_URL}/cart/health`, { headers: HEADERS });
    const ok = check(res, {
      'cart: health 200': (r) => r.status === 200,
    });
    errorRate.add(!ok);
  });

  sleep(0.5);

  // ── Order Service Health ─────────────────────────────────
  group('Order Service Health', () => {
    const res = http.get(`${BASE_URL}/orders/health`, { headers: HEADERS });
    const ok = check(res, {
      'orders: health 200': (r) => r.status === 200,
    });
    errorRate.add(!ok);
  });

  sleep(0.5);

  // ── Payment Service Health ───────────────────────────────
  group('Payment Service Health', () => {
    const res = http.get(`${BASE_URL}/payments/health`, { headers: HEADERS });
    const ok = check(res, {
      'payments: health 200': (r) => r.status === 200,
    });
    errorRate.add(!ok);
  });

  sleep(0.5);

  // ── Frontend ─────────────────────────────────────────────
  group('Frontend', () => {
    const frontendUrl = __ENV.FRONTEND_URL || 'https://nexacommerce.com';
    const res = http.get(frontendUrl);
    const ok = check(res, {
      'frontend: status 200': (r) => r.status === 200,
      'frontend: has content': (r) => r.body.length > 1000,
    });
    errorRate.add(!ok);
  });

  sleep(1);
}

export function handleSummary(data) {
  const passed = data.metrics.checks?.values?.rate > 0.99;
  const errorRateVal = data.metrics.error_rate?.values?.rate;
  const p99 = data.metrics.http_req_duration?.values?.['p(99)'];

  const result = {
    passed,
    error_rate: errorRateVal,
    p99_latency_ms: p99,
    timestamp: new Date().toISOString(),
  };

  console.log(`\n${passed ? '✅' : '❌'} Smoke Test ${passed ? 'PASSED' : 'FAILED'}`);
  console.log(`Error Rate: ${(errorRateVal * 100).toFixed(3)}%`);
  console.log(`P99 Latency: ${p99?.toFixed(0)}ms`);

  return {
    'scripts/load-testing/results/smoke-result.json': JSON.stringify(result, null, 2),
    stdout: `\nSmoke Test Result: ${passed ? 'PASSED ✅' : 'FAILED ❌'}\n`,
  };
}
