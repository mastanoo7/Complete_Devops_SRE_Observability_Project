const express = require("express");
const morgan = require("morgan");

const PORT = process.env.PORT || 8085;
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY || "sk_test_placeholder";

const app = express();
app.disable("x-powered-by");
app.use(morgan("combined"));
app.use(express.json({ limit: "1mb" }));

app.get("/health/live", (_req, res) => res.status(200).json({ status: "UP" }));
app.get("/health/ready", (_req, res) =>
  res.status(200).json({ status: "UP", stripeConfigured: STRIPE_SECRET_KEY !== "sk_test_placeholder" })
);

// Minimal payment API for local dev.
app.post("/api/v1/payments/intent", (req, res) => {
  const { orderId, amount, currency } = req.body || {};
  if (!orderId || typeof amount !== "number") {
    return res.status(400).json({ error: "invalid_request", message: "orderId and amount are required" });
  }
  return res.status(201).json({
    id: `pi_${Math.random().toString(16).slice(2)}`,
    orderId,
    amount,
    currency: currency || "USD",
    status: "requires_payment_method",
  });
});

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`payment-service listening on :${PORT}`);
});

