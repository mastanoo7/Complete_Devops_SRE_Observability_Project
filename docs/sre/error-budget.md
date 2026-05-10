# Error Budget — NexaCommerce

## Overview
Error budgets quantify how much unreliability is acceptable. They create a shared language between product and SRE teams for deployment velocity vs. reliability.

---

## Error Budget Calculation

```
Error Budget = 1 - SLO Target

Example (99.9% SLO):
  Error Budget = 1 - 0.999 = 0.001 = 0.1%
  
  Monthly budget:
  30 days × 24h × 60min = 43,200 minutes
  0.1% × 43,200 = 43.2 minutes of allowed downtime/month
```

---

## Error Budget by Service

| Service | SLO | Monthly Budget | Budget in Minutes |
|---------|-----|---------------|-------------------|
| Payment Service | 99.99% | 0.01% | 4.3 min |
| Order Service | 99.95% | 0.05% | 21.6 min |
| Auth Service | 99.9% | 0.1% | 43.2 min |
| Product Service | 99.9% | 0.1% | 43.2 min |
| Search Service | 99.5% | 0.5% | 216 min |
| Platform (overall) | 99.9% | 0.1% | 43.2 min |

---

## Error Budget Tracking

### Prometheus Queries

```promql
# Current error budget remaining (30-day window)
# Returns 1.0 = 100% remaining, 0.0 = 0% remaining
1 - (
  (1 - sum(rate(http_requests_total{namespace="nexacommerce-prod",code=~"5.."}[30d]))
       / sum(rate(http_requests_total{namespace="nexacommerce-prod"}[30d])))
  / (1 - 0.999)
)

# Error budget burn rate (1h window)
sum(rate(http_requests_total{namespace="nexacommerce-prod",code=~"5.."}[1h]))
/ sum(rate(http_requests_total{namespace="nexacommerce-prod"}[1h]))
/ 0.001
```

---

## Error Budget Policy

### Budget > 50% Remaining
- ✅ Normal deployment velocity
- ✅ Feature deployments allowed
- ✅ Experiments and risky changes allowed
- ✅ Chaos engineering experiments allowed

### Budget 25–50% Remaining
- ⚠️ Increased monitoring frequency
- ⚠️ Slow down risky deployments
- ⚠️ Focus reliability work on top error sources
- ✅ Normal feature deployments still allowed

### Budget 10–25% Remaining
- 🔴 Freeze non-critical feature deployments
- 🔴 All hands on reliability improvements
- 🔴 Weekly error budget review with engineering leads
- ✅ Critical bug fixes only

### Budget < 10% Remaining
- 🚨 **Freeze ALL deployments** (except P1 fixes)
- 🚨 Incident review required for all outages
- 🚨 SRE escalation to VP Engineering
- 🚨 Executive notification
- 🚨 Post-mortem for every incident

---

## Error Budget Reviews

### Weekly Review (SRE Team)
- Current budget remaining per service
- Top error sources this week
- Deployments that consumed budget
- Reliability improvements shipped

### Monthly Review (Engineering + Product)
- Budget consumed vs. features shipped
- Reliability investment decisions
- SLO target adjustments if needed
- Upcoming risky changes

---

## Grafana Dashboard

Error Budget dashboard shows:
- Budget remaining (gauge, 0-100%)
- Budget burn rate (time series)
- Top error sources (table)
- Deployment events overlay
- Projected budget exhaustion date

Access: https://grafana.nexacommerce.com/d/error-budget

---

## Related Documents
- [SLIs/SLOs/SLAs](slis-slos-slas.md)
- [Alerting Strategy](alerting-strategy.md)
- [Recording Rules](../../monitoring/prometheus/rules/recording-rules.yaml)
