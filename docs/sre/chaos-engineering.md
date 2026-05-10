# Chaos Engineering — NexaCommerce SRE

## Overview
This document covers the chaos engineering strategy, experiment catalog, and GameDay procedures for NexaCommerce.

> See also: [Chaos Engineering README](../../chaos-engineering/README.md) for the full maturity model and experiment catalog.

---

## Why Chaos Engineering?

1. **Verify resilience mechanisms actually work** — not just that they exist
2. **Build confidence** in the system under failure conditions
3. **Find weaknesses** before customers do
4. **Validate SLO compliance** during failures
5. **Train on-call engineers** in a controlled environment

---

## Chaos Maturity Model

| Level | Description | Status |
|-------|-------------|--------|
| 1 — Basic | Pod restarts, node drains | ✅ Active |
| 2 — Network | Latency, packet loss, DNS failure | ✅ Active |
| 3 — Resource | CPU/memory stress, disk pressure | ✅ Active |
| 4 — Application | Dependency failures, slow responses | 🔄 In Progress |
| 5 — Multi-cloud | Cloud provider failure simulation | 📋 Planned |

---

## Experiment Catalog

### Weekly Experiments (Automated)

```bash
# Run weekly chaos suite
make chaos-run EXP=pod-delete
make chaos-run EXP=network-latency
make chaos-run EXP=cpu-stress
```

| Experiment | Target | Expected Outcome |
|-----------|--------|-----------------|
| Pod Delete (33%) | All services | HPA replaces pods < 30s, SLO maintained |
| Network Latency (2s) | Order→Payment | Circuit breaker opens, graceful degradation |
| CPU Stress (90%) | Auth service | HPA scales up, auth still available |
| Node Drain | 1 of 3 AZs | Pods reschedule, no downtime |

### Monthly Experiments

| Experiment | Target | Expected Outcome |
|-----------|--------|-----------------|
| Database Failover | Aurora primary | Auto-failover < 60s, RPO = 0 |
| Redis Failure | ElastiCache | Cart service degrades gracefully |
| Kafka Partition | MSK broker | Events queue, no data loss |
| DNS Failure | CoreDNS | Services use cached DNS |

---

## Running Experiments

### Pre-Experiment Checklist

```bash
# 1. Check error budget (must be > 20%)
bash scripts/sre/check-slos.sh

# 2. Verify no active incidents
kubectl get events -n nexacommerce-prod --sort-by='.lastTimestamp' | tail -10

# 3. Open monitoring dashboards
# Grafana: https://grafana.nexacommerce.com/d/slo-overview

# 4. Notify team in Slack #chaos-engineering
```

### Apply Experiment

```bash
# Apply LitmusChaos experiment
kubectl apply -f chaos-engineering/experiments/pod-delete.yaml

# Monitor in real-time
watch -n 5 'kubectl get pods -n nexacommerce-prod | grep -v Running'

# Check SLO during experiment
watch -n 10 'bash scripts/sre/check-slos.sh'
```

### Stop Experiment

```bash
# Stop specific experiment
kubectl patch chaosengine pod-delete-product-service \
  -n nexacommerce-prod \
  --type=json \
  -p='[{"op":"replace","path":"/spec/engineState","value":"stop"}]'

# Emergency stop all experiments
kubectl delete chaosengines --all -n nexacommerce-prod
```

---

## GameDay Procedures

### Monthly GameDay (2 hours)

```
09:00 — Brief: Review hypothesis, success criteria
09:15 — Run pod-level chaos experiments
09:45 — Run network chaos experiments
10:15 — Run node-level chaos
10:45 — Review results, document findings
11:00 — Action items and retrospective
```

### Quarterly DR Drill (4 hours)

```
09:00 — Brief: DR scenario overview
09:30 — Simulate AZ failure (drain 1 AZ)
10:00 — Simulate database primary failure
10:30 — Simulate full cloud failure (tabletop)
11:00 — Validate RTO/RPO targets met
11:30 — Document results, update runbooks
12:00 — Retrospective and action items
```

---

## Hypothesis Template

```
HYPOTHESIS: When [failure condition], the system will [expected behavior]
because [resilience mechanism].

STEADY STATE: [Metric] is [value]

EXPERIMENT: [What we will do]

EXPECTED OUTCOME: [What should happen]

ACTUAL OUTCOME: [Fill after experiment]

VERDICT: Pass / Fail

ACTION ITEMS: [If failed, what to fix]
```

---

## Results Tracking

All results stored in:
- `chaos-engineering/results/` — JSON result files
- Grafana Chaos Dashboard: https://grafana.nexacommerce.com/d/chaos
- Jira: Chaos experiment tickets

---

## Related Documents
- [Chaos Experiments](../../chaos-engineering/experiments/)
- [Chaos Engineering README](../../chaos-engineering/README.md)
- [SLIs/SLOs](slis-slos-slas.md)
- [Incident Management](incident-management.md)
