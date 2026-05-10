// ============================================================
// k6 Load Test — NexaCommerce Full Platform
// Simulates realistic ecommerce traffic patterns
// ============================================================

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { randomIntBetween, randomItem } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

// ── Custom Metrics ────────────────────────────────────────
const errorRate        = new Rate('error_rate');
const checkoutDuration = new Trend('checkout_duration', true);
const searchDuration   = new Trend('search_duration', true);
const orderCreated     = new Counter('orders_created');
const paymentSuccess   = new Counter('payments_success');

// ── Test Configuration ────────────────────────────────────
export const options = {
  scenarios: {
    // Smoke test: verify basic functionality
    smoke: {
      executor: 'constant-vus',
      vus: 5,
      duration: '2m',
      tags: { scenario: 'smoke' },
      exec: 'smokeTest',
    },

    // Load test: normal production traffic
    load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '5m',  target: 100  },  // Ramp up
        { duration: '10m', target: 500  },  // Normal load
        { duration: '5m',  target: 1000 },  // Peak load
        { duration: '10m', target: 1000 },  // Sustain peak
        { duration: '5m',  target: 0    },  // Ramp down
      ],
      tags: { scenario: 'load' },
      exec: 'loadTest',
    },

    // Stress test: find breaking point
    stress: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '5m',  target: 500  },
        { duration: '5m',  target: 1000 },
        { duration: '5m',  target: 2000 },
        { duration: '5m',  target: 3000 },
        { duration: '5m',  target: 0    },
      ],
      tags: { scenario: 'stress' },
      exec: 'stressTest',
    },

    // Spike test: sudden traffic burst
    spike: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m',  target: 100  },  // Baseline
        { duration: '30s', target: 5000 },  // Spike!
        { duration: '3m',  target: 5000 },  // Sustain spike
        { duration: '30s', target: 100  },  // Drop
        { duration: '2m',  target: 100  },  // Recovery
      ],
      tags: { scenario: 'spike' },
      exec: 'spikeTest',
    },
  },

  // SLO thresholds — test fails if breached
  thresholds: {
    // Availability SLO: 99.9%
    'error_rate': [{ threshold: 'rate<0.001', abortOnFail: false }],

    // Latency SLOs
    'http_req_duration{scenario:load}': [
      { threshold: 'p(95)<200', abortOnFail: false },
      { threshold: 'p(99)<500', abortOnFail: false },
    ],
    'checkout_duration': [
      { threshold: 'p(95)<3000', abortOnFail: false },
      { threshold: 'p(99)<5000', abortOnFail: false },
    ],
    'search_duration': [
      { threshold: 'p(95)<500', abortOnFail: false },
      { threshold: 'p(99)<1000', abortOnFail: false },
    ],

    // HTTP status checks
    'http_req_failed': ['rate<0.01'],
  },
};

// ── Configuration ─────────────────────────────────────────
const BASE_URL = __ENV.BASE_URL || 'https://api.nexacommerce.com';
const FRONTEND_URL = __ENV.FRONTEND_URL || 'https://nexacommerce.com';

const HEADERS = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'X-Load-Test': 'true',
};

// Test data
const SEARCH_TERMS = ['laptop', 'phone', 'headphones', 'keyboard', 'monitor', 'tablet'];
const PRODUCT_IDS  = ['prod-001', 'prod-002', 'prod-003', 'prod-004', 'prod-005'];

// ── Helper Functions ──────────────────────────────────────
function authenticate() {
  const res = http.post(`${BASE_URL}/auth/login`, JSON.stringify({
    email: `loadtest+${randomIntBetween(1, 10000)}@nexacommerce.com`,
    password: 'LoadTest123!',
  }), { headers: HEADERS });

  check(res, {
    'auth: status 200': (r) => r.status === 200,
    'auth: has token': (r) => r.json('access_token') !== undefined,
  });

  errorRate.add(res.status !== 200);
  return res.json('access_token');
}

function getAuthHeaders(token) {
  return { ...HEADERS, 'Authorization': `Bearer ${token}` };
}

// ── Smoke Test ────────────────────────────────────────────
export function smokeTest() {
  group('Smoke: Health Checks', () => {
    const res = http.get(`${BASE_URL}/health`);
    check(res, { 'health: status 200': (r) => r.status === 200 });
  });

  group('Smoke: Product List', () => {
    const res = http.get(`${BASE_URL}/products?limit=10`, { headers: HEADERS });
    check(res, {
      'products: status 200': (r) => r.status === 200,
      'products: has items': (r) => r.json('items') !== undefined,
    });
  });

  sleep(1);
}

// ── Load Test (Realistic User Journey) ───────────────────
export function loadTest() {
  const token = authenticate();
  const authHeaders = getAuthHeaders(token);

  // 60% browse products
  group('Browse Products', () => {
    const searchTerm = randomItem(SEARCH_TERMS);
    const startTime = Date.now();

    const searchRes = http.get(
      `${BASE_URL}/search?q=${searchTerm}&limit=20`,
      { headers: authHeaders }
    );
    searchDuration.add(Date.now() - startTime);

    check(searchRes, {
      'search: status 200': (r) => r.status === 200,
      'search: has results': (r) => r.json('total') > 0,
    });
    errorRate.add(searchRes.status !== 200);

    sleep(randomIntBetween(1, 3));

    // View product detail
    const productId = randomItem(PRODUCT_IDS);
    const detailRes = http.get(
      `${BASE_URL}/products/${productId}`,
      { headers: authHeaders }
    );
    check(detailRes, { 'product detail: status 200': (r) => r.status === 200 });
    errorRate.add(detailRes.status !== 200);
  });

  sleep(randomIntBetween(1, 2));

  // 30% add to cart
  if (Math.random() < 0.3) {
    group('Add to Cart', () => {
      const cartRes = http.post(
        `${BASE_URL}/cart/items`,
        JSON.stringify({
          productId: randomItem(PRODUCT_IDS),
          quantity: randomIntBetween(1, 3),
        }),
        { headers: authHeaders }
      );
      check(cartRes, { 'cart: item added': (r) => r.status === 200 || r.status === 201 });
      errorRate.add(cartRes.status >= 400);
    });
  }

  sleep(randomIntBetween(1, 3));

  // 10% complete checkout
  if (Math.random() < 0.1) {
    group('Checkout', () => {
      const startTime = Date.now();

      const orderRes = http.post(
        `${BASE_URL}/orders/checkout`,
        JSON.stringify({
          shippingAddress: {
            street: '123 Test St',
            city: 'San Francisco',
            state: 'CA',
            zip: '94105',
            country: 'US',
          },
          paymentMethod: {
            type: 'card',
            token: 'tok_visa_test',
          },
        }),
        { headers: authHeaders }
      );

      checkoutDuration.add(Date.now() - startTime);

      const success = check(orderRes, {
        'checkout: order created': (r) => r.status === 201,
        'checkout: has order id': (r) => r.json('orderId') !== undefined,
      });

      if (success) {
        orderCreated.add(1);
        paymentSuccess.add(1);
      }
      errorRate.add(orderRes.status >= 400);
    });
  }

  sleep(randomIntBetween(2, 5));
}

// ── Stress Test ───────────────────────────────────────────
export function stressTest() {
  // Simplified stress test — just product browsing
  const res = http.get(
    `${BASE_URL}/products?limit=20&page=${randomIntBetween(1, 10)}`,
    { headers: HEADERS }
  );
  check(res, { 'stress: status ok': (r) => r.status < 500 });
  errorRate.add(res.status >= 500);
  sleep(0.5);
}

// ── Spike Test ────────────────────────────────────────────
export function spikeTest() {
  // Simulate flash sale traffic
  const res = http.get(
    `${BASE_URL}/products/flash-sale`,
    { headers: HEADERS }
  );
  check(res, { 'spike: status ok': (r) => r.status < 500 });
  errorRate.add(res.status >= 500);
  sleep(0.1);
}

// ── Summary ───────────────────────────────────────────────
export function handleSummary(data) {
  const summary = {
    timestamp: new Date().toISOString(),
    scenarios: Object.keys(options.scenarios),
    metrics: {
      error_rate: data.metrics.error_rate?.values?.rate,
      p95_latency: data.metrics.http_req_duration?.values?.['p(95)'],
      p99_latency: data.metrics.http_req_duration?.values?.['p(99)'],
      checkout_p95: data.metrics.checkout_duration?.values?.['p(95)'],
      orders_created: data.metrics.orders_created?.values?.count,
      payments_success: data.metrics.payments_success?.values?.count,
    },
    thresholds_passed: Object.values(data.metrics).every(
      m => !m.thresholds || Object.values(m.thresholds).every(t => t.ok)
    ),
  };

  return {
    'scripts/load-testing/results/summary.json': JSON.stringify(summary, null, 2),
    stdout: `\n📊 Load Test Summary\n${JSON.stringify(summary.metrics, null, 2)}\n`,
  };
}
