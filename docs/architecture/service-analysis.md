# NexaCommerce — Complete Service Analysis
> Step-by-step breakdown of every service, its logic, data flows, and inter-service relationships.

---

## Table of Contents

1. [Platform Overview](#1-platform-overview)
2. [Technology Stack Summary](#2-technology-stack-summary)
3. [Service Catalogue](#3-service-catalogue)
4. [Frontend Architecture](#4-frontend-architecture)
5. [Backend Services — Deep Dive](#5-backend-services--deep-dive)
   - [5.1 API Gateway](#51-api-gateway-nodejs--port-8080)
   - [5.2 Auth Service](#52-auth-service-go--port-8081)
   - [5.3 Product Service](#53-product-service-java-spring-boot--port-8082)
   - [5.4 Cart Service](#54-cart-service-nodejs--port-8083)
   - [5.5 Order Service](#55-order-service-java-spring-boot--port-8084)
   - [5.6 Payment Service](#56-payment-service-nodejs--port-8085)
   - [5.7 Inventory Service](#57-inventory-service-python-fastapi--port-8086)
   - [5.8 Notification Service](#58-notification-service-nodejs--port-8087)
   - [5.9 Search Service](#59-search-service-nodejs--port-8088)
6. [Data Stores](#6-data-stores)
7. [Messaging — Kafka Event Bus](#7-messaging--kafka-event-bus)
8. [End-to-End User Journeys](#8-end-to-end-user-journeys)
   - [8.1 User Registration & Login](#81-user-registration--login-flow)
   - [8.2 Product Discovery & Search](#82-product-discovery--search-flow)
   - [8.3 Add to Cart](#83-add-to-cart-flow)
   - [8.4 Checkout & Order Placement](#84-checkout--order-placement-flow)
   - [8.5 Order Fulfilment & Notification](#85-order-fulfilment--notification-flow)
9. [Service Dependency Map](#9-service-dependency-map)
10. [Network Topology](#10-network-topology)
11. [Observability Stack](#11-observability-stack)
12. [Security Architecture](#12-security-architecture)
13. [Kubernetes Production Setup](#13-kubernetes-production-setup)
14. [Key Design Patterns](#14-key-design-patterns)

---

## 1. Platform Overview

**NexaCommerce** is a cloud-native, microservices-based e-commerce platform designed for enterprise scale with:

- A **Next.js 14** frontend (SSR + client components)
- **9 independent backend microservices** written in Go, Java, Python, and Node.js
- **Event-driven communication** via Apache Kafka
- **Synchronous REST** communication via the API Gateway
- Multi-cloud infrastructure (AWS EKS, Azure AKS, GCP GKE) managed by Terraform
- Full observability: Prometheus + Grafana + Loki + OpenTelemetry + Jaeger

---

## 2. Technology Stack Summary

| Layer | Technology | Purpose |
|---|---|---|
| Frontend | Next.js 14, TypeScript, Tailwind CSS | SSR/CSR UI |
| API Gateway | Node.js, Express, http-proxy-middleware | Edge routing & reverse proxy |
| Auth Service | Go 1.22, Gin, Zap | JWT/OAuth2 authentication |
| Product Service | Java 17, Spring Boot 3.2 | Product catalogue & categories |
| Cart Service | Node.js, Express | Shopping cart management |
| Order Service | Java 17, Spring Boot 3.2, Spring Kafka | Order lifecycle management |
| Payment Service | Node.js | Payment processing (Stripe) |
| Inventory Service | Python 3.12, FastAPI, Uvicorn | Stock tracking & reservation |
| Notification Service | Node.js | Email/push notifications |
| Search Service | Node.js, Express, Elasticsearch | Full-text product search |
| Primary DB | PostgreSQL 15 | Relational data (auth, products, orders, payments, inventory) |
| Session/Cache | Redis 7 | JWT token store, cart cache, rate limiting |
| Event Bus | Apache Kafka (Confluent 7.5) | Async inter-service events |
| Document Store | MongoDB 7 | Notification history/templates |
| Search Index | Elasticsearch 8.12 | Product full-text search index |
| Container Orchestration | Kubernetes (EKS/AKS/GKE) | Production workloads |
| Service Mesh | Istio | mTLS, traffic management, observability |
| Secrets | HashiCorp Vault | Runtime secret injection |
| Metrics | Prometheus + Grafana | Dashboards & alerting |
| Logging | Loki + Promtail | Log aggregation |
| Tracing | OpenTelemetry + Jaeger | Distributed tracing |

---

## 3. Service Catalogue

```
Port  Service              Language    DB              Kafka Role
────  ───────────────────  ──────────  ──────────────  ──────────────────────────
3000  Frontend             TypeScript  —               —
8080  API Gateway          Node.js     Redis (cache)   —
8081  Auth Service         Go          PostgreSQL       —
8082  Product Service      Java        PostgreSQL+ES    Producer (product.*)
8083  Cart Service         Node.js     Redis            —
8084  Order Service        Java        PostgreSQL       Producer + Consumer
8085  Payment Service      Node.js     PostgreSQL       Producer (payment.*)
8086  Inventory Service    Python      PostgreSQL       Consumer (order.*)
8087  Notification Service Node.js     MongoDB          Consumer (order.*, payment.*)
8088  Search Service       Node.js     Elasticsearch    Consumer (product.*)
```

---

## 4. Frontend Architecture

### 4.1 Application Structure

```
frontend/
├── app/                          ← Next.js 14 App Router
│   ├── layout.tsx                ← Root layout (Inter font, metadata, OG tags)
│   ├── page.tsx                  ← Home page (SSR — Hero, Categories, Features)
│   ├── auth/login/page.tsx       ← Login + Register (Client Component)
│   ├── products/page.tsx         ← Product listing with filters (SSR)
│   ├── cart/page.tsx             ← Shopping cart (Client Component)
│   ├── checkout/page.tsx         ← Multi-step checkout wizard (Client Component)
│   └── orders/page.tsx           ← Order history & tracking (SSR)
└── src/lib/api-client.ts         ← Typed Axios HTTP client singleton
```

### 4.2 Rendering Strategy

| Page | Rendering | Reason |
|---|---|---|
| `page.tsx` (Home) | **SSR** | SEO — hero, categories, featured products |
| `products/page.tsx` | **SSR** | SEO — search results, category pages, `searchParams` |
| `orders/page.tsx` | **SSR** | Static metadata, server-fetched order list |
| `auth/login/page.tsx` | **CSR** (`'use client'`) | Interactive form state (login/register toggle) |
| `cart/page.tsx` | **CSR** (`'use client'`) | Real-time quantity updates, local state |
| `checkout/page.tsx` | **CSR** (`'use client'`) | Multi-step wizard state machine |

### 4.3 API Client (`api-client.ts`)

The singleton `ApiClient` class wraps Axios with:

- **Base URL**: `NEXT_PUBLIC_API_URL` → `https://api.nexacommerce.com` (points to API Gateway on port 8080)
- **Request interceptor**: Reads `access_token` from `localStorage` and attaches `Authorization: Bearer <token>` header to every request
- **Response interceptor**: On `401 Unauthorized`, attempts silent token refresh via `POST /api/v1/auth/refresh`. If refresh fails, clears tokens and redirects to `/auth/login`

**Complete API surface exposed to the frontend:**

```
Auth:
  POST /api/v1/auth/login          → returns AuthTokens (stores accessToken in localStorage)
  POST /api/v1/auth/logout         → clears token
  POST /api/v1/auth/register       → creates User
  GET  /api/v1/auth/me             → returns current User profile
  POST /api/v1/auth/refresh        → silent token refresh (called automatically on 401)

Products:
  GET  /api/v1/products            → PaginatedResponse<Product> (filter: category, price, sort, page)
  GET  /api/v1/products/:slug      → Product (single product detail)
  GET  /api/v1/categories          → Category[] (full category tree)

Search:
  GET  /api/v1/search?q=...        → SearchResult { products, total, query, facets }

Cart:
  GET    /api/v1/cart              → Cart (current user's cart)
  POST   /api/v1/cart/items        → add { productId, quantity } → Cart
  PUT    /api/v1/cart/items/:id    → update quantity → Cart
  DELETE /api/v1/cart/items/:id    → remove item → Cart
  DELETE /api/v1/cart              → clear entire cart

Orders:
  POST /api/v1/orders/checkout     → place order { shippingAddress, paymentMethod } → Order
  GET  /api/v1/orders              → PaginatedResponse<Order>
  GET  /api/v1/orders/:id          → Order (single order detail)
```

### 4.4 Key TypeScript Data Types

```typescript
// Product catalogue
interface Product {
  id, name, slug, description, price, currency,
  images: string[], category: Category,
  sku, inStock, stockCount, rating, reviewCount, createdAt
}

// Shopping cart
interface Cart {
  id, userId, items: CartItem[], subtotal, itemCount, updatedAt
}
interface CartItem {
  id, productId, product: Product, quantity, unitPrice, totalPrice
}

// Order lifecycle
interface Order {
  id, userId,
  status: 'pending' | 'confirmed' | 'processing' | 'shipped' | 'delivered' | 'cancelled',
  items: OrderItem[], subtotal, shippingCost, tax, total,
  shippingAddress: Address, createdAt, updatedAt
}

// Auth
interface AuthTokens { accessToken, expiresIn, tokenType }
interface User { id, email, firstName, lastName, createdAt }
```

### 4.5 Checkout State Machine

The checkout page (`checkout/page.tsx`) implements a 3-step wizard using React `useState`:

```
Step 1: 'shipping'
  ├── Collects: firstName, lastName, street, city, state, zip, country
  └── onNext() → Step 2

Step 2: 'payment'
  ├── Collects: cardNumber, expiry, CVV, nameOnCard
  └── onNext() → Step 3 | onBack() → Step 1

Step 3: 'review'
  ├── Shows: order summary, totals (subtotal + shipping + tax)
  └── onPlace() → POST /api/v1/orders/checkout → [Order Confirmed screen]
                  onBack() → Step 2
```

**Pricing logic (Cart page):**
```
subtotal = sum(item.price × item.quantity)
shipping = subtotal > $50 ? $0 (free) : $9.99
tax      = subtotal × 8%
total    = subtotal + shipping + tax
```

### 4.6 Order Status Display

The Orders page maps order status to visual badges:

| Status | Badge Color | Icon |
|---|---|---|
| `pending` | Yellow | ⏳ |
| `confirmed` | Blue | ✅ |
| `processing` | Purple | ⚙️ |
| `shipped` | Indigo | 🚚 |
| `delivered` | Green | 📦 |
| `cancelled` | Red | ❌ |

---

## 5. Backend Services — Deep Dive

### 5.1 API Gateway (Node.js — Port 8080)

**Source**: `backend/api-gateway/src/index.js`  
**Role**: Single entry point for all frontend traffic. Pure reverse proxy — zero business logic.

**Routing table:**

```
Incoming Path            → Upstream Service         Upstream Port
───────────────────────────────────────────────────────────────────
/api/v1/auth/*           → auth-service             :8081
/api/v1/products/*       → product-service          :8082
/api/v1/cart/*           → cart-service             :8083
/api/v1/orders/*         → order-service            :8084
/api/v1/payments/*       → payment-service          :8085
/api/v1/search/*         → search-service           :8088
/health/live             → (local handler) 200 UP
/health/ready            → (local handler) lists all upstream URLs
```

**Key behaviours:**
- Uses `http-proxy-middleware` with `changeOrigin: true` — rewrites the `Host` header to the upstream service name
- Path rewriting is 1:1 passthrough — `/api/v1/auth/login` arrives at auth-service as `/api/v1/auth/login`
- Logs all requests with Morgan `combined` format (Apache-style access logs)
- In production (Kubernetes), upstream URLs are injected via ConfigMap as Kubernetes DNS names (e.g. `http://auth-service`, `http://cart-service`)
- HPA scales from **3 → 20 replicas** at 70% CPU utilisation
- PodDisruptionBudget ensures minimum 2 replicas during node drains

**Dependencies:**
- Redis (for rate limiting — planned)
- All downstream microservices

**Planned features (TODOs in code):**
- JWT validation / token introspection before proxying (currently passes all requests through)
- Redis-backed rate limiting per IP/user
- Request ID (`X-Request-ID`) propagation for distributed tracing

---

### 5.2 Auth Service (Go — Port 8081)

**Source**: `backend/auth-service/main.go`  
**Role**: Issues and validates JWT tokens. Manages user identity. Supports OAuth2 social login.  
**Framework**: Gin v1.10 + Zap structured logging

**Complete endpoint list:**

```
POST /api/v1/auth/login              → validate credentials → return JWT access token + refresh token
POST /api/v1/auth/logout             → invalidate token (add to Redis blacklist)
POST /api/v1/auth/refresh            → issue new access token from valid refresh token
POST /api/v1/auth/register           → create new user account (hash password with bcrypt)
GET  /api/v1/auth/me                 → return authenticated user profile [requires authMiddleware]
GET  /api/v1/auth/oauth/:provider    → initiate OAuth2 flow (Google, GitHub)
GET  /api/v1/auth/callback/:provider → handle OAuth2 callback, issue tokens
POST /api/v1/auth/introspect         → validate token for Kong/API Gateway token introspection
GET  /health/live                    → liveness probe → { status: "UP" }
GET  /health/ready                   → readiness (checks DB + Redis) → { status, components }
GET  /health/startup                 → startup probe → { status: "UP" }
GET  /metrics                        → Prometheus metrics endpoint
```

**JWT token lifecycle:**

```
Login Request
    │
    ▼
Auth Service validates credentials (bcrypt compare)
    │
    ├── access_token  (JWT, 15 min TTL)  → returned in response body
    │                                       stored in localStorage by frontend
    │
    └── refresh_token (opaque, 7 day TTL) → stored in Redis
                                             returned as HttpOnly cookie

On API Request:
    Frontend attaches: Authorization: Bearer <access_token>
    API Gateway forwards header to upstream service

On 401 (token expired):
    Frontend calls POST /api/v1/auth/refresh
    Auth Service validates refresh_token from Redis
    Issues new access_token (15 min)
    Frontend retries original request

On Logout:
    access_token added to Redis blacklist (TTL = remaining token lifetime)
    refresh_token deleted from Redis
```

**Middleware stack** (applied to every request in order):
1. `gin.Recovery()` — panic recovery, returns 500 instead of crashing
2. `loggingMiddleware(logger)` — structured JSON logs: method, path, status, duration
3. `metricsMiddleware()` — Prometheus counter/histogram instrumentation (TODO)
4. `tracingMiddleware()` — OpenTelemetry span creation (TODO)

**Production (Kubernetes) specifics:**
- 3 replicas minimum, spread across availability zones (pod anti-affinity by zone)
- Vault agent sidecar injects `JWT_SECRET`, `DATABASE_URL`, `REDIS_URL` at pod startup
- IRSA (IAM Roles for Service Accounts) for AWS Secrets Manager access
- ConfigMap sets: `JWT_EXPIRY=15m`, `REFRESH_TOKEN_EXPIRY=7d`, `JWT_ISSUER=nexacommerce-auth`
- Tracing endpoint: `http://jaeger-collector.monitoring:14268/api/traces`

**Data stores:**
- **PostgreSQL** (`auth_db`): users table, oauth_providers, refresh_tokens
- **Redis**: refresh token store (`refresh:{userId}`), token blacklist (`blacklist:{jti}`)

---

### 5.3 Product Service (Java Spring Boot — Port 8082)

**Source**: `backend/product-service/` (Dockerfile present; Java source not shown)  
**Role**: Manages the product catalogue, categories, pricing, and product metadata.  
**Framework**: Spring Boot 3.2, Java 17

**Inferred endpoints** (from API client contract + docker-compose environment):

```
GET  /api/v1/products                → paginated product list
                                       query params: page, pageSize, category, sort, minPrice, maxPrice
GET  /api/v1/products/:slug          → single product detail (by URL slug)
GET  /api/v1/categories              → full category tree
POST /api/v1/products                → create product (admin only)
PUT  /api/v1/products/:id            → update product details/price (admin only)
DELETE /api/v1/products/:id          → soft-delete product (admin only)
GET  /actuator/health/liveness       → Spring Boot liveness probe
GET  /actuator/health/readiness      → Spring Boot readiness probe
GET  /actuator/prometheus            → Prometheus metrics
```

**Data stores:**
- **PostgreSQL** (`product_db`): products, categories, product_images, pricing
- **Redis**: product detail cache (TTL-based, invalidated on update)
- **Elasticsearch**: product search index (synced via Kafka events)

**Kafka events produced:**
- `product.created` — when a new product is published
- `product.updated` — when product details, price, or stock hint changes
- `product.deleted` — when a product is removed from catalogue

**Caching strategy:**
```
GET /api/v1/products/:slug
  1. Check Redis cache key: product:{slug}
  2. Cache HIT  → return cached JSON (fast path)
  3. Cache MISS → SELECT from PostgreSQL → store in Redis (TTL ~5 min) → return
```

---

### 5.4 Cart Service (Node.js — Port 8083)

**Source**: `backend/cart-service/src/index.js`  
**Role**: Manages per-user shopping carts. Stateless service backed by Redis in production.

**Complete endpoint list:**

```
GET    /api/v1/cart              → get cart for user identified by X-User-ID header
POST   /api/v1/cart/items        → add item { sku, qty } to cart
DELETE /api/v1/cart/items/:sku   → remove item by SKU from cart
GET    /health/live              → { status: "UP" }
GET    /health/ready             → { status: "UP" }
```

**Cart data model:**
```javascript
// In-memory (dev) / Redis HASH (prod)
carts: Map<userId, {
  items: Array<{ sku: string, qty: number }>
}>
```

**Add-to-cart logic:**
```javascript
POST /api/v1/cart/items  { sku: "nexa-keyboard", qty: 2 }
  1. Extract userId from X-User-ID header (set by API Gateway after JWT validation)
     → falls back to "anonymous" if header missing
  2. Validate: sku required, qty must be positive number
     → 400 Bad Request if invalid
  3. Load existing cart (or create empty { items: [] })
  4. If SKU already in cart → increment qty (no duplicate items)
     If SKU not in cart → push { sku, qty } to items array
  5. Save cart back to store
  6. Return 201 with updated cart
```

**Remove-from-cart logic:**
```javascript
DELETE /api/v1/cart/items/:sku
  1. Load cart for userId
  2. Filter out item with matching SKU
  3. Save updated cart
  4. Return 200 with updated cart
```

**Key design decisions:**
- Cart stores only `sku` + `qty` — **no prices** (prices fetched from Product Service at checkout time to always use current pricing)
- Anonymous cart support — carts persist under `"anonymous"` key until user logs in
- In production: `Map` replaced by Redis `HSET cart:{userId} items <json>` with TTL

**Inter-service dependency:**
- Reads from **Product Service** (`PRODUCT_SERVICE_URL`) to validate SKU existence and fetch current price at checkout

---

### 5.5 Order Service (Java Spring Boot — Port 8084)

**Source**: `backend/order-service/src/main/resources/application.yml`, `pom.xml`  
**Role**: Core order lifecycle management. Orchestrates checkout by coordinating Payment and Inventory services. Publishes order events to Kafka.  
**Framework**: Spring Boot 3.2, Spring Kafka, Lombok, Java 17

**Complete endpoint list:**

```
POST /api/v1/orders/checkout         → place order (orchestrates Payment + Inventory)
GET  /api/v1/orders                  → list user orders (paginated, auth required)
GET  /api/v1/orders/:id              → get single order detail
PUT  /api/v1/orders/:id/cancel       → cancel order (if status allows)
GET  /actuator/health/liveness       → liveness probe
GET  /actuator/health/readiness      → readiness probe (checks DB + Kafka)
GET  /actuator/prometheus            → Prometheus metrics
```

**Order status lifecycle:**

```
                    ┌─────────────────────────────────────────────┐
                    │                                             │
  [Cart] ──POST──► pending ──► confirmed ──► processing ──► shipped ──► delivered
                      │                                             │
                      └─────────────────── cancelled ◄─────────────┘
                      (payment failed or user cancels before shipping)
```

**Checkout orchestration — step by step:**

```
POST /api/v1/orders/checkout  { shippingAddress, paymentMethod: { type, token } }

Step 1: Fetch cart items
  → GET /api/v1/cart  (Cart Service)
  → Enrich with current prices from Product Service

Step 2: Reserve inventory (synchronous)
  → POST /api/v1/inventory/{sku}/reserve?qty=N  (Inventory Service)
  → If 409 Conflict (insufficient stock) → return 422 to client
  → Repeat for each cart item

Step 3: Process payment (synchronous)
  → POST /api/v1/payments  { amount, currency, token }  (Payment Service)
  → If payment fails → release inventory reservations → return 402 to client

Step 4: Persist order
  → INSERT order + order_items into PostgreSQL (order_db)
  → Set status = 'confirmed'

Step 5: Publish event (async)
  → Kafka topic: order.created  { orderId, userId, items, total, shippingAddress }

Step 6: Clear cart
  → DELETE /api/v1/cart  (Cart Service)

Step 7: Return Order object to client
```

**Kafka event consumption:**
```
Consumes: payment.completed → UPDATE order SET status='processing' WHERE id=?
Consumes: payment.failed    → UPDATE order SET status='cancelled' WHERE id=?
                              → Release inventory reservations
```

**Kafka topics produced:**
- `order.created` — consumed by Notification Service (send confirmation email) and Inventory Service
- `order.updated` — consumed by Notification Service (send status update email)

**Production config (Kubernetes ConfigMap):**
```yaml
KAFKA_TOPIC_ORDER_CREATED:  "order.created"
KAFKA_TOPIC_ORDER_UPDATED:  "order.updated"
KAFKA_CONSUMER_GROUP:       "order-service-prod"
PAYMENT_SERVICE_URL:        "http://payment-service"
INVENTORY_SERVICE_URL:      "http://inventory-service"
ORDER_TIMEOUT_MINUTES:      "30"
```

**JVM tuning (Kubernetes):**
```
JAVA_OPTS: -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC
```
Resources: 500m CPU / 512Mi RAM (requests) → 2000m CPU / 2Gi RAM (limits)

---

### 5.6 Payment Service (Node.js — Port 8085)

**Source**: `backend/payment-service/` (Dockerfile present; source not shown)  
**Role**: Processes payments via Stripe. Publishes payment outcome events to Kafka.

**Inferred endpoints:**

```
POST /api/v1/payments            → charge card using Stripe token
GET  /api/v1/payments/:id        → get payment status
POST /api/v1/payments/refund     → issue refund for an order
GET  /health/live
GET  /health/ready
```

**Stripe integration flow:**
```
Frontend (browser)
  │  Stripe.js tokenises card data client-side
  │  → card number NEVER touches NexaCommerce servers
  │  → returns payment token (e.g. "tok_visa")
  │
  ▼
POST /api/v1/orders/checkout { paymentMethod: { type: "card", token: "tok_visa" } }
  │
  ▼
Order Service → POST /api/v1/payments { amount, currency, token }
  │
  ▼
Payment Service → Stripe API: stripe.charges.create({ amount, currency, source: token })
  │
  ├── Success → INSERT payment record → Kafka: payment.completed
  └── Failure → INSERT payment record → Kafka: payment.failed
```

**Kafka events produced:**
- `payment.completed` — `{ paymentId, orderId, amount, currency, stripeChargeId }`
- `payment.failed` — `{ paymentId, orderId, errorCode, errorMessage }`

**Data store**: PostgreSQL (`payment_db`) — payments table, refunds, stripe_events (webhook log)

**Environment:**
```
STRIPE_SECRET_KEY: sk_live_... (injected via Vault)
KAFKA_BROKERS:     kafka:9092
DATABASE_URL:      postgres://...@postgres:5432/payment_db
```

---

### 5.7 Inventory Service (Python FastAPI — Port 8086)

**Source**: `backend/inventory-service/main.py`  
**Role**: Tracks stock levels. Provides atomic stock reservation to prevent overselling.  
**Framework**: FastAPI 0.111, Uvicorn 0.30

**Complete endpoint list:**

```
GET  /api/v1/inventory/{sku}           → { sku: str, available: int }
POST /api/v1/inventory/{sku}/reserve   → reserve qty units (atomic decrement)
                                         query param: qty (int)
                                         header: X-User-ID (for audit)
GET  /health/live                      → { status: "UP" }
GET  /health/ready                     → { status: "UP" }
GET  /__port                           → { port: int }  (debug endpoint)
```

**Stock reservation logic (atomic):**

```python
POST /api/v1/inventory/{sku}/reserve?qty=2

Validation chain:
  1. qty <= 0          → HTTP 400  detail="qty_must_be_positive"
  2. sku not in STOCK  → HTTP 404  detail="sku_not_found"
  3. STOCK[sku] < qty  → HTTP 409  detail="insufficient_stock"
  4. STOCK[sku] -= qty (atomic decrement)
  5. Return 200: { sku, reserved: qty, remaining: STOCK[sku] }
```

**Error codes reference:**

| HTTP Status | Detail Code | Meaning |
|---|---|---|
| 400 | `qty_must_be_positive` | Requested quantity is zero or negative |
| 404 | `sku_not_found` | SKU does not exist in inventory |
| 409 | `insufficient_stock` | Available stock < requested quantity |

**Local dev stock (hardcoded):**
```python
STOCK = {
  "nexa-hoodie":   42,
  "nexa-mug":     120,
  "nexa-keyboard":  0   # ← out of stock example
}
```

**Production behaviour:**
- In-memory dict replaced by PostgreSQL (`inventory_db`) with row-level locking (`SELECT FOR UPDATE`)
- Kafka consumer listens to `order.created` for post-checkout stock reconciliation
- Stock release on order cancellation via `order.cancelled` event

**Called by**: Order Service (synchronous HTTP) during checkout Step 2

---

### 5.8 Notification Service (Node.js — Port 8087)

**Source**: `backend/notification-service/Dockerfile`  
**Role**: Sends transactional emails and push notifications. Purely **event-driven** — never called directly via HTTP by other services.  
**Framework**: Node.js 20

**Kafka topics consumed:**

| Topic | Trigger | Notification Sent |
|---|---|---|
| `order.created` | New order placed | "Order Confirmation" email with order summary |
| `order.updated` | Order status changed | "Order Status Update" email (shipped/delivered) |
| `payment.completed` | Payment successful | "Payment Receipt" email with amount |
| `payment.failed` | Payment declined | "Payment Failed" alert with retry instructions |

**Email delivery:**
- **Development**: MailHog SMTP (port 1025) — catches all emails, viewable at `http://localhost:8025`
- **Production**: AWS SES or SendGrid via SMTP relay

**Data store**: MongoDB (`notifications` database)
```
Collection: notification_logs
  { _id, userId, type, channel, status, payload, sentAt, deliveredAt }

Collection: templates
  { _id, name, subject, htmlBody, textBody, variables[] }

Collection: delivery_status
  { _id, notificationId, provider, messageId, status, updatedAt }
```

**Environment:**
```
MONGODB_URI:   mongodb://nexacommerce:...@mongodb:27017/notifications
KAFKA_BROKERS: kafka:9092
SMTP_HOST:     mailhog (dev) / ses.us-east-1.amazonaws.com (prod)
SMTP_PORT:     1025 (dev) / 587 (prod)
```

---

### 5.9 Search Service (Node.js — Port 8088)

**Source**: `backend/search-service/src/index.js`  
**Role**: Full-text product search backed by Elasticsearch.  
**Framework**: Node.js, Express

**Complete endpoint list:**

```
GET /api/v1/search?q=<query>&category=<cat>  → { total: int, items: Product[] }
GET /health/live                              → { status: "UP" }
GET /health/ready                            → { status: "UP", index, docs: count }
```

**Search logic (dev — in-memory):**

```javascript
GET /api/v1/search?q=keyboard&category=electronics

1. Normalise query string to lowercase
2. Filter products where:
     name.toLowerCase().includes(q)  OR
     slug.toLowerCase().includes(q)  OR
     category.toLowerCase().includes(q)
3. If category param provided → further filter by exact category match
4. Return { total: filtered.length, items: filtered }
```

**In-memory product catalogue (dev):**
```javascript
[
  { id: "prod-1", slug: "nexa-hoodie",   name: "Nexa Hoodie",              category: "apparel",     price: 59.00  },
  { id: "prod-2", slug: "nexa-mug",      name: "Nexa Mug",                 category: "accessories", price: 14.99  },
  { id: "prod-3", slug: "nexa-keyboard", name: "Nexa Mechanical Keyboard", category: "electronics", price: 129.00 }
]
```

**Production behaviour:**
- Queries forwarded to Elasticsearch index `nexacommerce-products` using the ES Node.js client
- Full-text scoring, facets (category, price range, rating), and pagination supported
- Index kept in sync via Kafka `product.*` events consumed from Product Service

**Environment:**
```
ELASTICSEARCH_URL: http://elasticsearch:9200
INDEX_PRODUCTS:    nexacommerce-products
```

---

## 6. Data Stores

### 6.1 PostgreSQL — Relational Data

Single PostgreSQL 15 instance with **5 separate databases** (one per service, Database-per-Service pattern):

```
Database        Owner Service       Key Tables
──────────────  ──────────────────  ─────────────────────────────────────────────
auth_db         Auth Service        users, oauth_providers, refresh_tokens
product_db      Product Service     products, categories, product_images, pricing
order_db        Order Service       orders, order_items, shipping_addresses
payment_db      Payment Service     payments, refunds, stripe_events
inventory_db    Inventory Service   stock_levels, reservations, stock_history
```

**Rules:**
- Each service owns its database exclusively — no cross-database queries
- Inter-service data access is always via HTTP API or Kafka events
- Initialised by `scripts/db/init-multiple-dbs.sh` on first startup

### 6.2 Redis — Cache & Session Store

Shared Redis 7 instance, `maxmemory 512mb`, `allkeys-lru` eviction:

| Service | Usage | Key Pattern |
|---|---|---|
| Auth Service | Refresh token store | `refresh:{userId}` |
| Auth Service | Token blacklist (logout) | `blacklist:{jti}` |
| Cart Service | Cart persistence (prod) | `cart:{userId}` |
| API Gateway | Rate limiting counters | `ratelimit:{ip}:{window}` |
| Product Service | Product detail cache | `product:{slug}`, `category:{id}` |

### 6.3 Elasticsearch — Search Index

Single-node Elasticsearch 8.12 (dev). Multi-node cluster in production.

- **Index**: `nexacommerce-products`
- **Documents**: product records with full-text fields (name, description, category, tags)
- **Security**: `xpack.security.enabled=false` in dev; TLS + auth in prod
- **Updated by**: Search Service consuming Kafka `product.*` events

### 6.4 MongoDB — Document Store

MongoDB 7 used exclusively by the Notification Service:

- **Database**: `notifications`
- **Collections**: `notification_logs`, `templates`, `delivery_status`
- Chosen for flexible schema (different notification types have different payloads)

### 6.5 Data Store Summary

```
Service              Read From                Write To
───────────────────  ───────────────────────  ──────────────────────────────
Auth Service         PostgreSQL, Redis         PostgreSQL, Redis
Product Service      PostgreSQL, Redis, ES     PostgreSQL, Redis, Kafka
Cart Service         Redis                     Redis
Order Service        PostgreSQL                PostgreSQL, Kafka
Payment Service      PostgreSQL                PostgreSQL, Kafka
Inventory Service    PostgreSQL                PostgreSQL
Notification Service MongoDB                   MongoDB
Search Service       Elasticsearch             Elasticsearch (via Kafka)
```

---

## 7. Messaging — Kafka Event Bus

Apache Kafka (Confluent 7.5) with Zookeeper for coordination.
Kafka UI available at `http://localhost:8090` in local dev.

### 7.1 Topic Map

```
Topic                Producer              Consumers
───────────────────  ────────────────────  ──────────────────────────────────────
order.created        Order Service         Notification Service, Inventory Service
order.updated        Order Service         Notification Service
payment.completed    Payment Service       Order Service, Notification Service
payment.failed       Payment Service       Order Service, Notification Service
product.created      Product Service       Search Service
product.updated      Product Service       Search Service
product.deleted      Product Service       Search Service
```

### 7.2 Event Payload Examples

**`order.created`**
```json
{
  "orderId": "ORD-2024-001",
  "userId": "usr-123",
  "items": [
    { "sku": "nexa-keyboard", "qty": 1, "unitPrice": 129.00 }
  ],
  "subtotal": 129.00,
  "shippingCost": 0.00,
  "tax": 10.32,
  "total": 139.32,
  "shippingAddress": { "street": "123 Main St", "city": "SF", "zip": "94105" },
  "timestamp": "2024-01-15T10:00:00Z"
}
```

**`payment.completed`**
```json
{
  "paymentId": "pay_abc123",
  "orderId": "ORD-2024-001",
  "amount": 139.32,
  "currency": "USD",
  "stripeChargeId": "ch_xyz789",
  "timestamp": "2024-01-15T10:00:05Z"
}
```

**`payment.failed`**
```json
{
  "paymentId": "pay_abc124",
  "orderId": "ORD-2024-002",
  "errorCode": "card_declined",
  "errorMessage": "Your card was declined.",
  "timestamp": "2024-01-15T10:01:00Z"
}
```

### 7.3 Consumer Groups

Each consuming service has its own consumer group, ensuring every service processes every event independently:

```
Consumer Group                  Topics Consumed
──────────────────────────────  ────────────────────────────
order-service-prod              payment.completed, payment.failed
notification-service-prod       order.created, order.updated, payment.completed, payment.failed
search-service-prod             product.created, product.updated, product.deleted
inventory-service-prod          order.created
```

---

## 8. End-to-End User Journeys

### 8.1 User Registration & Login Flow

```
Browser                  API Gateway        Auth Service        PostgreSQL    Redis
  │                           │                   │                  │           │
  │── POST /api/v1/auth/register ────────────────►│                  │           │
  │                           │── proxy ─────────►│                  │           │
  │                           │                   │── INSERT user ──►│           │
  │                           │                   │◄─ 201 Created ───│           │
  │◄── 201 { user } ──────────│◄──────────────────│                  │           │
  │                           │                   │                  │           │
  │── POST /api/v1/auth/login ───────────────────►│                  │           │
  │                           │── proxy ─────────►│                  │           │
  │                           │                   │── SELECT user ──►│           │
  │                           │                   │── bcrypt verify  │           │
  │                           │                   │── SET refresh ──────────────►│
  │◄── 200 { accessToken } ───│◄──────────────────│                  │           │
  │  localStorage.set('access_token', token)      │                  │           │
```

**Silent token refresh (on 401):**
```
Browser (receives 401)
  │── POST /api/v1/auth/refresh (refresh cookie) ──► Auth Service
  │                                                       │── GET refresh:{userId} ──► Redis
  │                                                       │── issue new access_token (15m)
  │◄── 200 { accessToken } ────────────────────────────────
  │── retry original request with new token
```

---

### 8.2 Product Discovery & Search Flow

```
Browser                  API Gateway     Product Service    Redis       PostgreSQL
  │                           │                │              │              │
  │── GET /api/v1/products ──►│                │              │              │
  │                           │── proxy ──────►│              │              │
  │                           │                │── GET product:{slug} ──────►│ (cache check)
  │                           │                │  MISS → SELECT products ────►│
  │                           │                │◄─ rows ──────────────────────│
  │                           │                │── SET product:{slug} ───────►│ (cache fill)
  │◄── 200 PaginatedResponse ─│◄───────────────│              │              │
  │                           │                │              │              │
  │── GET /api/v1/search?q=keyboard ──────────►│              │              │
  │                           │── proxy ──────────────────────────────────────────► Search Service
  │                           │                                                          │
  │                           │                                                          │── ES query
  │◄── 200 { total, items } ──│◄─────────────────────────────────────────────────────────
```

---

### 8.3 Add to Cart Flow

```
Browser                  API Gateway     Cart Service       Redis
  │                           │                │              │
  │── POST /api/v1/cart/items ───────────────►│              │
  │   { sku: "nexa-keyboard", qty: 1 }        │              │
  │   Authorization: Bearer <token>           │              │
  │                           │── proxy ──────►│              │
  │                           │   X-User-ID: usr-123 (from JWT)
  │                           │                │── GET cart:usr-123 ─────────►│
  │                           │                │  existing item? → increment qty
  │                           │                │  new item? → push to array
  │                           │                │── SET cart:usr-123 ─────────►│
  │◄── 201 { items: [...] } ──│◄───────────────│              │
```

---

### 8.4 Checkout & Order Placement Flow

```
Browser          API Gateway    Order Service   Inventory Svc  Payment Svc   PostgreSQL   Kafka
  │                   │               │               │              │            │          │
  │── POST /checkout ►│               │               │              │            │          │
  │                   │── proxy ─────►│               │              │            │          │
  │                   │               │               │              │            │          │
  │                   │               │── POST /inventory/{sku}/reserve ─────────►│          │
  │                   │               │◄── 200 { reserved, remaining } ───────────│          │
  │                   │               │  (repeat for each item)       │            │          │
  │                   │               │               │              │            │          │
  │                   │               │── POST /payments { amount, token } ──────►│          │
  │                   │               │◄── 200 { paymentId } ─────────────────────│          │
  │                   │               │               │              │            │          │
  │                   │               │── INSERT order ─────────────────────────►│          │
  │                   │               │── PUBLISH order.created ─────────────────────────────►│
  │                   │               │── DELETE /cart ──────────────────────────►│          │
  │◄── 200 { order } ─│◄──────────────│               │              │            │          │
```

**Failure scenarios:**

| Failure Point | Action | HTTP Response |
|---|---|---|
| Inventory insufficient | Skip payment, return error | 422 Unprocessable Entity |
| Payment declined | Release inventory reservations | 402 Payment Required |
| DB write fails | Rollback, release inventory, refund | 500 Internal Server Error |

---

### 8.5 Order Fulfilment & Notification Flow

```
Kafka           Order Service    Notification Service    User (Email)
  │                   │                  │                    │
  │── payment.completed ─────────────────►│                   │
  │                   │                  │── send "Payment Receipt" email ──────►│
  │                   │                  │                    │                   │
  │── order.created ──►│                 │                    │                   │
  │                   │── UPDATE status='processing'          │                   │
  │                   │                  │                    │                   │
  │── order.created ──────────────────────►│                  │                   │
  │                   │                  │── send "Order Confirmation" email ────►│
  │                   │                  │                    │                   │
  │  [Shipping system updates status]    │                    │                   │
  │── order.updated ──►│                 │                    │                   │
  │                   │── UPDATE status='shipped'             │                   │
  │── order.updated ──────────────────────►│                  │                   │
  │                   │                  │── send "Your order has shipped!" ─────►│
```

---

## 9. Service Dependency Map

### 9.1 Synchronous Dependencies (HTTP)

```
                    ┌─────────────────────────────────────────────────┐
                    │                  FRONTEND                        │
                    │            (Next.js :3000)                       │
                    └──────────────────┬──────────────────────────────┘
                                       │ HTTPS
                                       ▼
                    ┌─────────────────────────────────────────────────┐
                    │               API GATEWAY                        │
                    │             (Node.js :8080)                      │
                    └──┬──────┬──────┬──────┬──────┬──────────────────┘
                       │      │      │      │      │
              /auth    │ /products   │ /cart│ /orders  /search
                       │      │      │      │      │
                       ▼      ▼      ▼      ▼      ▼
                    ┌────┐ ┌──────┐ ┌────┐ ┌─────┐ ┌──────┐
                    │Auth│ │Prod. │ │Cart│ │Order│ │Search│
                    │:8081│ │:8082 │ │:8083│ │:8084│ │:8088 │
                    └────┘ └──────┘ └────┘ └──┬──┘ └──────┘
                                               │
                                    ┌──────────┴──────────┐
                                    │                     │
                                    ▼                     ▼
                               ┌─────────┐          ┌─────────┐
                               │Inventory│          │Payment  │
                               │  :8086  │          │  :8085  │
                               └─────────┘          └─────────┘
```

### 9.2 Asynchronous Dependencies (Kafka)

```
Product Service ──── product.created ────────────────────► Search Service
                ──── product.updated ────────────────────► Search Service
                ──── product.deleted ────────────────────► Search Service

Order Service ────── order.created ─────────────────────► Notification Service
              ────── order.created ─────────────────────► Inventory Service
              ────── order.updated ─────────────────────► Notification Service

Payment Service ──── payment.completed ─────────────────► Order Service
                ──── payment.completed ─────────────────► Notification Service
                ──── payment.failed ─────────────────────► Order Service
                ──── payment.failed ─────────────────────► Notification Service
```

### 9.3 Data Store Dependencies

```
Service              PostgreSQL DB    Redis    Kafka    MongoDB    Elasticsearch
───────────────────  ──────────────  ───────  ───────  ─────────  ─────────────
Auth Service         auth_db         ✓        —        —          —
Product Service      product_db      ✓        ✓        —          —
Cart Service         —               ✓        —        —          —
Order Service        order_db        —        ✓        —          —
Payment Service      payment_db      —        ✓        —          —
Inventory Service    inventory_db    —        ✓        —          —
Notification Service —               —        ✓        ✓          —
Search Service       —               —        ✓        —          ✓
```

---

## 10. Network Topology

### 10.1 Docker Compose Networks (Local Dev)

```
frontend-net:   frontend ←→ api-gateway ←→ kafka-ui ←→ grafana
backend-net:    api-gateway ←→ all microservices ←→ prometheus
data-net:       all microservices ←→ postgres, redis, kafka, elasticsearch, mongodb
monitoring-net: prometheus ←→ grafana ←→ loki ←→ promtail
```

**Port map (localhost):**

| Port | Service |
|---|---|
| 3000 | Frontend (Next.js) |
| 3001 | Grafana |
| 3100 | Loki |
| 8025 | MailHog Web UI |
| 8080 | API Gateway |
| 8081 | Auth Service |
| 8082 | Product Service |
| 8083 | Cart Service |
| 8084 | Order Service |
| 8085 | Payment Service |
| 8086 | Inventory Service |
| 8087 | Notification Service |
| 8088 | Search Service |
| 8090 | Kafka UI |
| 9090 | Prometheus |
| 9200 | Elasticsearch |
| 27017 | MongoDB |
| 29092 | Kafka (external) |
| 5432 | PostgreSQL |
| 6379 | Redis |

### 10.2 Kubernetes Network (Production)

All services run in namespace `nexacommerce-prod` as `ClusterIP` services.
Istio service mesh enforces mTLS between all pods.

```
Internet
    │
    ▼
[Ingress / Load Balancer]  (AWS ALB / GCP GLB / Azure AGW)
    │
    ▼
[Istio Ingress Gateway]
    │
    ▼
[api-gateway ClusterIP :80]  ← 3–20 pods (HPA)
    │
    ├──► [auth-service :80]         ← 3–15 pods
    ├──► [product-service :80]      ← 3–15 pods
    ├──► [cart-service :80]         ← 3–15 pods
    ├──► [order-service :80]        ← 3–15 pods
    ├──► [payment-service :80]      ← 3–15 pods
    └──► [search-service :80]       ← 3–15 pods

[order-service] ──► [inventory-service :80]
[order-service] ──► [payment-service :80]
```

---

## 11. Observability Stack

### 11.1 Metrics (Prometheus + Grafana)

Every service exposes a `/metrics` (or `/actuator/prometheus`) endpoint scraped by Prometheus.

**Prometheus scrape config** (via pod annotations):
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port:   "8080"   # or 9090 for metrics sidecar
  prometheus.io/path:   "/metrics"
```

**Grafana dashboards** (`monitoring/grafana/dashboards/`):
- SLO Overview dashboard — error rate, latency percentiles, availability

**Alert rules** (`monitoring/prometheus/rules/service-alerts.yaml`):
- High error rate (5xx > threshold)
- High latency (p99 > SLO)
- Pod crash loops
- Kafka consumer lag

### 11.2 Logging (Loki + Promtail)

- **Promtail** runs as DaemonSet, tails `/var/log` and Docker container logs
- **Loki** aggregates and indexes logs
- **Grafana** provides log exploration UI (LogQL queries)
- All services use structured JSON logging (Zap for Go, Logback JSON for Java, Morgan for Node.js)

### 11.3 Distributed Tracing (OpenTelemetry + Jaeger)

- Auth Service configured with `TRACING_ENDPOINT: http://jaeger-collector.monitoring:14268/api/traces`
- OpenTelemetry Collector (`monitoring/opentelemetry/otel-collector.yaml`) receives spans and forwards to Jaeger
- Traces correlate requests across: Frontend → API Gateway → Auth/Product/Cart/Order → Payment/Inventory

### 11.4 Health Probes

Every service implements the Kubernetes probe pattern:

| Probe | Path | Purpose |
|---|---|---|
| Liveness | `/health/live` | Is the process alive? Restart if failing |
| Readiness | `/health/ready` | Is the service ready to receive traffic? |
| Startup | `/health/startup` | Has the service finished initialising? (Java services) |

---

## 12. Security Architecture

### 12.1 Authentication & Authorisation

```
Request flow with JWT:

Browser ──► API Gateway ──► [TODO: JWT introspect] ──► Upstream Service
                                     │
                                     ▼
                               Auth Service
                               POST /auth/introspect
                               → { active: true, userId, roles }
```

Currently the API Gateway passes all requests through without JWT validation (marked as TODO). In the intended design:
1. API Gateway calls `POST /api/v1/auth/introspect` for every protected request
2. Auth Service validates the JWT signature and expiry
3. API Gateway injects `X-User-ID` and `X-User-Roles` headers before proxying

### 12.2 Secrets Management (HashiCorp Vault)

Vault agent sidecar pattern used for Auth Service and Order Service:

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "auth-service"
  vault.hashicorp.com/agent-inject-secret-config: "secret/data/nexacommerce/auth-service"
```

Secrets injected at pod startup into `/vault/secrets/` — never stored in Kubernetes Secrets or environment variables in plaintext.

### 12.3 Network Security

**Istio mTLS** (`kubernetes/overlays/prod/istio/peer-authentication.yaml`):
- All service-to-service communication encrypted with mutual TLS
- PeerAuthentication policy enforces `STRICT` mTLS mode in prod namespace

**Network Policies** (`kubernetes/base/network-policies/`):
- `default-deny.yaml` — deny all ingress/egress by default
- `allow-rules.yaml` — explicit allow rules per service

**Kubernetes Security Context** (all pods):
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
```

### 12.4 Runtime Security

- **Falco** (`security/falco/falco-rules.yaml`) — runtime threat detection (syscall monitoring)
- **Kyverno** (`security/kyverno/policies.yaml`) — admission controller policies
- **OPA Gatekeeper** (`security/opa/gatekeeper-constraints.yaml`) — policy enforcement

---

## 13. Kubernetes Production Setup

### 13.1 Deployment Strategy

All services use **RollingUpdate** with zero downtime:
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # one extra pod during update
    maxUnavailable: 0  # never reduce below desired count
```

### 13.2 High Availability

| Resource | Configuration |
|---|---|
| Min replicas | 3 (all services) |
| Pod anti-affinity | Required — spread across availability zones |
| TopologySpreadConstraints | maxSkew: 1 across hostnames |
| PodDisruptionBudget | minAvailable: 2 (all services) |

### 13.3 Auto-scaling (HPA)

| Service | Min | Max | CPU Target |
|---|---|---|---|
| API Gateway | 3 | 20 | 70% |
| Auth Service | 3 | 15 | 70% CPU + 80% Memory |
| Order Service | 3 | 15 | 70% |
| All others | 3 | 15 | 70% |

### 13.4 Resource Budgets

| Service | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---|---|---|---|---|
| API Gateway | 250m | 1000m | 256Mi | 1Gi |
| Auth Service | 250m | 500m | 256Mi | 512Mi |
| Order Service | 500m | 2000m | 512Mi | 2Gi |

### 13.5 GitOps with ArgoCD

Deployments managed by ArgoCD (`argocd/`):
- `argocd/root-app.yaml` — App of Apps pattern
- `argocd/apps/nexacommerce-prod.yaml` — production application
- `argocd/apps/nexacommerce-dev-staging.yaml` — dev/staging application

Kustomize overlays per environment:
```
kubernetes/
├── base/           ← base manifests (all services)
└── overlays/
    ├── dev/        ← dev overrides (lower replicas, debug flags)
    ├── staging/    ← staging overrides (Istio mTLS strict)
    └── prod/       ← prod overrides (Istio, full security policies)
```

---

## 14. Key Design Patterns

### 14.1 Patterns Used

| Pattern | Where Applied | Purpose |
|---|---|---|
| **API Gateway** | `api-gateway` | Single entry point, routing, cross-cutting concerns |
| **Database per Service** | All services | Loose coupling, independent scaling |
| **Event-Driven Architecture** | Kafka topics | Async decoupling between Order, Payment, Inventory, Notification |
| **CQRS (partial)** | Search Service | Separate read model (Elasticsearch) from write model (PostgreSQL) |
| **Saga (Choreography)** | Checkout flow | Distributed transaction across Order → Payment → Inventory via events |
| **Circuit Breaker** | Planned (Istio) | Prevent cascade failures between services |
| **Sidecar** | Vault agent, Istio proxy | Inject secrets and mTLS without app changes |
| **App of Apps** | ArgoCD | GitOps management of multiple Kubernetes applications |
| **Token Refresh** | API Client | Silent JWT refresh on 401 for seamless UX |
| **Optimistic UI** | Cart page | Local state updates before API confirmation |

### 14.2 Service Communication Summary

```
Synchronous (HTTP REST):
  Frontend → API Gateway → Auth Service
  Frontend → API Gateway → Product Service
  Frontend → API Gateway → Cart Service
  Frontend → API Gateway → Order Service → Payment Service
  Frontend → API Gateway → Order Service → Inventory Service
  Frontend → API Gateway → Search Service

Asynchronous (Kafka Events):
  Order Service    ──publish──► Notification Service (email)
  Order Service    ──publish──► Inventory Service (stock reconcile)
  Payment Service  ──publish──► Order Service (status update)
  Payment Service  ──publish──► Notification Service (receipt/alert)
  Product Service  ──publish──► Search Service (index sync)
```

### 14.3 Known Gaps & TODOs

| Gap | Location | Impact |
|---|---|---|
| JWT validation in API Gateway | `api-gateway/src/index.js` | All routes currently unprotected at gateway level |
| Prometheus metrics | `auth-service/main.go` metricsMiddleware | No metrics collected yet |
| OpenTelemetry tracing | `auth-service/main.go` tracingMiddleware | No traces emitted yet |
| Cart → Product price sync | `cart-service/src/index.js` | Cart stores SKU only; price lookup not implemented |
| Inventory release on cancel | `inventory-service/main.py` | No cancel/release endpoint implemented |
| Notification service source | `notification-service/` | Only Dockerfile present; business logic not shown |
| Payment service source | `payment-service/` | Only Dockerfile present; Stripe integration not shown |
| Product service source | `product-service/` | Only Dockerfile present; Spring Boot source not shown |

---

*Document generated by analysing: `frontend/app/**`, `frontend/src/lib/api-client.ts`, `backend/*/src/**`, `backend/*/main.*`, `docker-compose.yml`, `kubernetes/base/**`, `kubernetes/overlays/prod/**`*