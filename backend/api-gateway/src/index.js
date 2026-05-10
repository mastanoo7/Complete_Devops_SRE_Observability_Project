const express = require("express");
const morgan = require("morgan");
const { createProxyMiddleware } = require("http-proxy-middleware");

const PORT = process.env.PORT || 8080;

const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || "http://localhost:8081";
const PRODUCT_SERVICE_URL = process.env.PRODUCT_SERVICE_URL || "http://localhost:8082";
const CART_SERVICE_URL = process.env.CART_SERVICE_URL || "http://localhost:8083";
const ORDER_SERVICE_URL = process.env.ORDER_SERVICE_URL || "http://localhost:8084";
const PAYMENT_SERVICE_URL = process.env.PAYMENT_SERVICE_URL || "http://localhost:8085";
const SEARCH_SERVICE_URL = process.env.SEARCH_SERVICE_URL || "http://localhost:8088";

const app = express();
app.disable("x-powered-by");
app.use(morgan("combined"));

app.get("/health/live", (_req, res) => res.status(200).json({ status: "UP" }));
app.get("/health/ready", (_req, res) =>
  res.status(200).json({
    status: "UP",
    upstreams: {
      auth: AUTH_SERVICE_URL,
      product: PRODUCT_SERVICE_URL,
      cart: CART_SERVICE_URL,
      order: ORDER_SERVICE_URL,
      payment: PAYMENT_SERVICE_URL,
    },
  })
);

// Basic path-based routing for local dev.
app.use(
  "/api/v1/auth",
  createProxyMiddleware({ target: AUTH_SERVICE_URL, changeOrigin: true, pathRewrite: { "^/api/v1/auth": "/api/v1/auth" } })
);
app.use(
  "/api/v1/products",
  createProxyMiddleware({
    target: PRODUCT_SERVICE_URL,
    changeOrigin: true,
    pathRewrite: { "^/api/v1/products": "/api/v1/products" },
  })
);
app.use(
  "/api/v1/cart",
  createProxyMiddleware({ target: CART_SERVICE_URL, changeOrigin: true, pathRewrite: { "^/api/v1/cart": "/api/v1/cart" } })
);
app.use(
  "/api/v1/orders",
  createProxyMiddleware({
    target: ORDER_SERVICE_URL,
    changeOrigin: true,
    pathRewrite: { "^/api/v1/orders": "/api/v1/orders" },
  })
);
app.use(
  "/api/v1/payments",
  createProxyMiddleware({
    target: PAYMENT_SERVICE_URL,
    changeOrigin: true,
    pathRewrite: { "^/api/v1/payments": "/api/v1/payments" },
  })
);
app.use(
  "/api/v1/search",
  createProxyMiddleware({
    target: SEARCH_SERVICE_URL,
    changeOrigin: true,
    pathRewrite: { "^/api/v1/search": "/api/v1/search" },
  })
);

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`api-gateway listening on :${PORT}`);
});

