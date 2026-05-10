const express = require("express");
const morgan = require("morgan");

const PORT = process.env.PORT || 8083;

const app = express();
app.disable("x-powered-by");
app.use(morgan("combined"));
app.use(express.json({ limit: "1mb" }));

// Simple in-memory cart store for local dev
const carts = new Map(); // userId -> { items: [{ sku, qty }] }

app.get("/health/live", (_req, res) => res.status(200).json({ status: "UP" }));
app.get("/health/ready", (_req, res) => res.status(200).json({ status: "UP" }));

app.get("/api/v1/cart", (req, res) => {
  const userId = req.header("X-User-ID") || "anonymous";
  res.json(carts.get(userId) || { items: [] });
});

app.post("/api/v1/cart/items", (req, res) => {
  const userId = req.header("X-User-ID") || "anonymous";
  const { sku, qty } = req.body || {};
  if (!sku || typeof qty !== "number" || qty <= 0) {
    return res.status(400).json({ error: "invalid_request", message: "sku and qty are required" });
  }
  const cart = carts.get(userId) || { items: [] };
  const existing = cart.items.find((i) => i.sku === sku);
  if (existing) existing.qty += qty;
  else cart.items.push({ sku, qty });
  carts.set(userId, cart);
  return res.status(201).json(cart);
});

app.delete("/api/v1/cart/items/:sku", (req, res) => {
  const userId = req.header("X-User-ID") || "anonymous";
  const sku = req.params.sku;
  const cart = carts.get(userId) || { items: [] };
  cart.items = cart.items.filter((i) => i.sku !== sku);
  carts.set(userId, cart);
  res.json(cart);
});

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`cart-service listening on :${PORT}`);
});

