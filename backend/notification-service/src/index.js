const express = require("express");
const morgan = require("morgan");

const PORT = process.env.PORT || 8087;

const app = express();
app.disable("x-powered-by");
app.use(morgan("combined"));
app.use(express.json({ limit: "1mb" }));

app.get("/health/live", (_req, res) => res.status(200).json({ status: "UP" }));
app.get("/health/ready", (_req, res) => res.status(200).json({ status: "UP" }));

// Minimal notification API for local dev.
app.post("/api/v1/notifications/email", (req, res) => {
  const { to, subject } = req.body || {};
  if (!to || !subject) {
    return res.status(400).json({ error: "invalid_request", message: "to and subject are required" });
  }
  return res.status(202).json({ status: "queued" });
});

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`notification-service listening on :${PORT}`);
});

