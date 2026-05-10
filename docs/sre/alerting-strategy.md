# Alerting Strategy — NexaCommerce

## Overview
NexaCommerce uses a **multi-window, multi-burn-rate** alerting strategy based on Google SRE principles. Alerts are actionable, routed to the right team, and linked to runbooks.

---

## Alert Design Principles

1. **Every alert must be actionable** — if you can't do anything about it, don't alert
2. **Link to runbook** — every alert has a runbook URL in annotations
3. **Correct severity** — P1 pages on-call, P3 sends Slack message
4. **Avoid alert fatigue** — tune thresholds, use inhibition rules
5. **Multi-window burn rate** — catch both fast and slow failures

---

## Alert Severity Levels

| Severity | Meaning | Channel | Response |
|----------|---------|---------|---------|
| `critical` | SLO breach or imminent breach | PagerDuty + Slack #alerts-critical | Page on-call immediately |
| `warning` | Degraded performance, approaching SLO | Slack #alerts-warning | Investigate within 30 min |
| `info` | Informational, no action needed | Slack #alerts-info | Review during business hours |

---

## Multi-Window Burn Rate Alerts

### Fast Burn (Catches sudden spikes)
```promql
# 14.4x burn rate over 1h = 2% budget consumed in 1h
# Triggers: Critical alert
(
  sum(rate(http_requests_total{code=~"5.."}[1h]))
  / sum(rate(http_requests_total[1h]))
) > (14.4 * 0.001)
```

### Slow Burn (Catches gradual degradation)
```promql
# 6x burn rate over 6h = 5% budget consumed in 6h
# Triggers: Warning alert
(
  sum(rate(http_requests_total{code=~"5.."}[6h]))
  / sum(rate(http_requests_total[6h]))
) > (6 * 0.001)
```

---

## Alert Categories

### SLO Alerts
| Alert | Condition | Severity | Runbook |
|-------|-----------|---------|---------|
| AvailabilitySLOBreach | Error rate > SLO threshold | Critical | [high-latency.md](../../runbooks/high-latency.md) |
| LatencySLOBreach | P99 > SLO threshold | Warning/Critical | [high-latency.md](../../runbooks/high-latency.md) |
| ErrorBudgetFastBurn | 14.4x burn rate | Critical | [incident-management.md](incident-management.md) |
| ErrorBudgetSlowBurn | 6x burn rate | Warning | [incident-management.md](incident-management.md) |

### Infrastructure Alerts
| Alert | Condition | Severity | Runbook |
|-------|-----------|---------|---------|
| PodCrashLooping | Restart rate > 0 | Warning | [pod-crashloop.md](../../runbooks/pod-crashloop.md) |
| NodeNotReady | Node status != Ready | Warning | [node-failure.md](../../runbooks/node-failure.md) |
| NodeHighCPU | CPU > 85% for 10min | Warning | [node-failure.md](../../runbooks/node-failure.md) |
| NodeDiskSpaceLow | Disk < 15% free | Critical | [node-failure.md](../../runbooks/node-failure.md) |
| DeploymentReplicasMismatch | Available != Desired | Warning | [pod-crashloop.md](../../runbooks/pod-crashloop.md) |

### Database Alerts
| Alert | Condition | Severity | Runbook |
|-------|-----------|---------|---------|
| AuroraHighConnections | Connections > 800 | Warning | [database-failover.md](../../runbooks/database-failover.md) |
| AuroraReplicationLag | Lag > 5s | Warning | [database-failover.md](../../runbooks/database-failover.md) |
| RedisHighMemory | Memory > 85% | Warning | [high-latency.md](../../runbooks/high-latency.md) |

### Business Alerts
| Alert | Condition | Severity | Team |
|-------|-----------|---------|------|
| OrderFailureRateHigh | Order failure > 5% | Critical | Orders |
| PaymentFailureRateHigh | Payment failure > 2% | Critical | Payments |
| CheckoutConversionDropped | Conversion < 30% | Warning | Product |

---

## Alert Routing (AlertManager)

```yaml
# Routing tree summary:
Critical alerts:
  payment-service → PagerDuty (payment team) + Slack #alerts-payment-critical
  SLO breach → PagerDuty (SRE) + Slack #alerts-slo
  Other critical → PagerDuty (on-call) + Slack #alerts-critical

Warning alerts:
  → Slack #alerts-warning

Business alerts:
  orders team → Slack #team-orders-alerts
  payments team → Slack #team-payments-alerts
```

---

## Alert Tuning

### Reducing False Positives
```yaml
# Add 'for' duration to avoid transient spikes
- alert: HighErrorRate
  expr: error_rate > 0.01
  for: 5m    # Must be true for 5 minutes before alerting
```

### Inhibition Rules
```yaml
# Suppress warning if critical already firing for same service
inhibit_rules:
  - source_match:
      severity: critical
    target_match:
      severity: warning
    equal: [service, namespace]
```

---

## On-Call Rotation

- **Primary**: 1-week rotation, all senior engineers
- **Secondary**: Backup if primary doesn't ack in 5 min
- **Escalation**: Engineering Manager after 15 min
- **Tool**: PagerDuty
- **Schedule**: https://nexacommerce.pagerduty.com/schedules

---

## Related Documents
- [Alert Rules](../../monitoring/prometheus/rules/service-alerts.yaml)
- [AlertManager Config](../../monitoring/prometheus/alertmanager.yml)
- [Incident Management](incident-management.md)
- [SLIs/SLOs/SLAs](slis-slos-slas.md)
