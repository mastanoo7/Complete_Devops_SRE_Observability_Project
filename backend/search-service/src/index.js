const express = require("express");
const morgan = require("morgan");

const PORT = process.env.PORT || 8088;
const INDEX_PRODUCTS = process.env.INDEX_PRODUCTS || "nexacommerce-products";

const app = express();
app.disable("x-powered-by");
app.use(morgan("combined"));
app.use(express.json({ limit: "1mb" }));

const products = [
  { id: "prod-1", slug: "nexa-hoodie", name: "Nexa Hoodie", category: "apparel", price: 59.0 },
  { id: "prod-2", slug: "nexa-mug", name: "Nexa Mug", category: "accessories", price: 14.99 },
  { id: "prod-3", slug: "nexa-keyboard", name: "Nexa Mechanical Keyboard", category: "electronics", price: 129.0 }
];

app.get("/health/live", (_req, res) => res.status(200).json({ status: "UP" }));
app.get("/health/ready", (_req, res) =>
  res.status(200).json({ status: "UP", index: INDEX_PRODUCTS, docs: products.length })
);

app.get("/api/v1/search", (req, res) => {
  const q = String(req.query.q || "").trim().toLowerCase();
  const category = String(req.query.category || "").trim().toLowerCase();

  let filtered = products;
  if (q) {
    filtered = filtered.filter(
      (p) => p.name.toLowerCase().includes(q) || p.slug.toLowerCase().includes(q) || p.category.toLowerCase().includes(q)
    );
  }
  if (category) {
    filtered = filtered.filter((p) => p.category.toLowerCase() === category);
  }

  res.json({ total: filtered.length, items: filtered });
});

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`search-service listening on :${PORT}`);
});

