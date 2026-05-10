# SLIs, SLOs, and SLAs — NexaCommerce

## Overview
This document defines the Service Level Indicators (SLIs), Service Level Objectives (SLOs), and Service Level Agreements (SLAs) for all NexaCommerce production services.

---

## SLI/SLO Framework

```
SLI = What we measure (metric)
SLO = Target we aim for (internal goal)
SLA = Commitment to customers (contractual)
Error Budget = 1 - SLO (allowed failure budget)
```

---

## Platform-Level SLOs

| Metric | SLI | SLO | SLA | Error Budget (30d) |
|--------|-----|-----|-----|-------------------|
| Availability | % successful requests | 99.9% | 99.5% | 43.8 min/month |
| Latency P99 | 99th percentile response time | < 500ms | < 1s | N/A |
| Latency P95 | 95th percentile response time | < 200ms | < 500ms | N/A |
| Error Rate | % 5xx responses | < 0.1% | < 0.5% | N/A |

---

## Per-Service SLOs

### 🔐 Auth Service
| SLI | SLO | Measurement Window | Alert Threshold |
|-----|-----|--------------------|-----------------|
| Availability | 99.9% | 30-day rolling | < 99.5% for 5min |
| Login P99 latency | < 200ms | 5-min rolling | > 500ms for 5min |
| Token validation P99 | < 50ms | 5-min rolling | > 100ms for 5min |
| Token refresh success rate | > 99.5% | 1-hour rolling | < 99% for 10min |

**Error Budget**: 43.8 minutes/month
**Prometheus SLI Query**:
```promql
sum(rate(http_requests_total{service="auth-service",code!~"5.."}[5m]))
/ sum(rate(http_requests_total{service="auth-service"}[5m]))
```

---

### 📦 Product Service
| SLI | SLO | Measurement Window | Alert Threshold |
|-----|-----|--------------------|-----------------|
| Availability | 99.9% | 30-day rolling | < 99.5% for 5min |
| Product list P99 | < 500ms | 5-min rolling | > 1s for 5min |
| Product detail P99 | < 200ms | 5-min rolling | > 500ms for 5min |
| Search P99 | < 300ms | 5-min rolling | > 800ms for 5min |
| Cache hit rate | > 80% | 1-hour rolling | < 60% for 15min |

---

### 🛒 Cart Service
| SLI | SLO | Measurement Window | Alert Threshold |
|-----|-----|--------------------|-----------------|
| Availability | 99.9% | 30-day rolling | < 99.5% for 5min |
| Add to cart P99 | < 100ms | 5-min rolling | > 300ms for 5min |
| Cart retrieval P99 | < 50ms | 5-min rolling | > 150ms for 5min |

---

### 📋 Order Service
| SLI | SLO | Measurement Window | Alert Threshold |
|-----|-----|--------------------|-----------------|
| Availability | 99.95% | 30-day rolling | < 99.9% for 2min |
| Order creation P99 | < 2s | 5-min rolling | > 5s for 5min |
| Order retrieval P99 | < 200ms | 5-min rolling | > 500ms for 5min |
| Order success rate | > 99% | 1-hour rolling | < 98% for 5min |

**Error Budget**: 21.9 minutes/month

---

### 💳 Payment Service (Strictest SLOs)
| SLI | SLO | Measurement Window | Alert Threshold |
|-----|-----|--------------------|-----------------|
| Availability | 99.99% | 30-day rolling | < 99.95% for 1min |
| Payment processing P99 | < 3s | 5-min rolling | > 5s for 2min |
| Payment success rate | > 99.5% | 1-hour rolling | < 99% for 2min |
| Refund processing P99 | < 5s | 5-min rolling | > 10s for 5min |
| Fraud detection latency | < 500ms | 5-min rolling | > 1s for 5min |

**Error Budget**: 4.38 minutes/month
**PCI-DSS Requirement**: 100% audit log completeness

---

### 📊 Inventory Service
| SLI | SLO | Measurement Window | Alert Threshold |
|-----|-----|--------------------|-----------------|
| Availability | 99.9% | 30-day rolling | < 99.5% for 5min |
| Stock check P99 | < 100ms | 5-min rolling | > 300ms for 5min |
| Reservation success rate | > 99.5% | 1-hour rolling | < 99% for 5min |

---

### 🔍 Search Service
| SLI | SLO | Measurement Window | Alert Threshold |
|-----|-----|--------------------|-----------------|
| Availability | 99.5% | 30-day rolling | < 99% for 10min |
| Search P99 | < 500ms | 5-min rolling | > 1s for 10min |
| Search relevance score | > 0.7 | Daily | < 0.6 for 1h |

---

## Error Budget Policy

### When Error Budget is > 50% remaining
- Normal development velocity
- Feature deployments allowed
- Experiments allowed

### When Error Budget is 25-50% remaining
- Increased monitoring
- Slow down risky deployments
- Focus on reliability improvements

### When Error Budget is 10-25% remaining
- Freeze non-critical feature deployments
- All hands on reliability
- Weekly error budget review

### When Error Budget is < 10% remaining
- **Freeze all deployments** except critical fixes
- Incident review required
- SRE escalation
- Executive notification

---

## SLO Measurement Queries

### 30-day Availability Window
```promql
# Overall platform availability
sum(rate(http_requests_total{namespace="nexacommerce-prod",code!~"5.."}[30d]))
/ sum(rate(http_requests_total{namespace="nexacommerce-prod"}[30d]))
```

### Error Budget Remaining
```promql
# Error budget consumed (target: 99.9%)
1 - (
  (1 - sum(rate(http_requests_total{namespace="nexacommerce-prod",code=~"5.."}[30d]))
       / sum(rate(http_requests_total{namespace="nexacommerce-prod"}[30d])))
  / (1 - 0.999)
)
```

### Multi-window Error Budget Burn Rate
```promql
# Fast burn (1h window, 14.4x burn rate)
(
  sum(rate(http_requests_total{namespace="nexacommerce-prod",code=~"5.."}[1h]))
  / sum(rate(http_requests_total{namespace="nexacommerce-prod"}[1h]))
) > (14.4 * 0.001)
```

---

## SLA Commitments (Customer-Facing)

| Tier | Availability SLA | Support Response | Credits |
|------|-----------------|-----------------|---------|
| Free | 99.5% | 48h | None |
| Pro | 99.9% | 4h | 10% per 0.1% below SLA |
| Enterprise | 99.95% | 1h | 25% per 0.05% below SLA |

---

## Related Documents
- [Error Budget Policy](error-budget.md)
- [Alerting Strategy](alerting-strategy.md)
- [Incident Management](incident-management.md)
- [Prometheus Alert Rules](../../monitoring/prometheus/rules/service-alerts.yaml)
