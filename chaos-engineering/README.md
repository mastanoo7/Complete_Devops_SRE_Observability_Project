# Chaos Engineering — NexaCommerce

## Overview
NexaCommerce uses **LitmusChaos** for systematic chaos engineering to proactively identify weaknesses before they cause production incidents.

---

## Philosophy

> "Hope is not a strategy. Chaos engineering is."

We run chaos experiments to:
1. **Verify** that our resilience mechanisms actually work
2. **Build confidence** in the system's behavior under failure
3. **Find weaknesses** before customers do
4. **Validate** SLO compliance during failures

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

### Pod-Level Experiments

| Experiment | Target | Frequency | Expected Outcome |
|-----------|--------|-----------|-----------------|
| Pod Delete | All services | Weekly | HPA replaces pods < 30s |
| Pod CPU Hog | Auth, Product | Bi-weekly | HPA scales up, SLO maintained |
| Pod Memory Hog | Search, Recommend | Bi-weekly | OOM kill, pod restarts cleanly |
| Container Kill | All services | Weekly | Service continues with remaining pods |

### Network Experiments

| Experiment | Target | Frequency | Expected Outcome |
|-----------|--------|-----------|-----------------|
| Network Latency (2s) | Order→Payment | Bi-weekly | Circuit breaker opens |
| Network Loss (10%) | Product service | Monthly | Retry logic handles gracefully |
| DNS Failure | All services | Monthly | Services use cached DNS |
| Network Partition | DB connection | Monthly | Connection pool recovers |

### Node-Level Experiments

| Experiment | Target | Frequency | Expected Outcome |
|-----------|--------|-----------|-----------------|
| Node Drain | 1 of 3 AZs | Monthly | Pods reschedule, no downtime |
| Node CPU Stress | Worker nodes | Monthly | Cluster autoscaler adds nodes |
| Node Disk Pressure | Worker nodes | Quarterly | Pods evicted, rescheduled |

---

## Experiment Execution Process

### Pre-Experiment Checklist
```bash
□ Error budget > 20% remaining
□ No active P1/P2 incidents
□ Monitoring dashboards open
□ Rollback plan documented
□ Stakeholders notified (for major experiments)
□ Steady state baseline captured
```

### Running an Experiment

```bash
# 1. Verify steady state
kubectl exec -n monitoring deploy/prometheus -- \
  promtool query instant \
  'sum(rate(http_requests_total{namespace="nexacommerce-prod",code=~"5.."}[5m]))'

# 2. Apply chaos experiment
kubectl apply -f chaos-engineering/experiments/pod-delete.yaml

# 3. Monitor in real-time
watch -n 5 'kubectl get pods -n nexacommerce-prod | grep -v Running'

# 4. Check SLO compliance during experiment
# Grafana: https://grafana.nexacommerce.com/d/slo-overview

# 5. Stop experiment if SLO breached
kubectl patch chaosengine pod-delete-product-service \
  -n nexacommerce-prod \
  --type=json \
  -p='[{"op":"replace","path":"/spec/engineState","value":"stop"}]'
```

### Post-Experiment Analysis

```bash
# Get experiment results
kubectl get chaosresult pod-delete-product-service-pod-delete \
  -n nexacommerce-prod -o yaml

# Check if probes passed
kubectl get chaosresult pod-delete-product-service-pod-delete \
  -n nexacommerce-prod \
  -o jsonpath='{.status.experimentStatus.verdict}'
```

---

## GameDay Schedule

### Monthly GameDay (2 hours)
- **Week 1**: Pod-level chaos (delete, CPU, memory)
- **Week 2**: Network chaos (latency, loss, partition)
- **Week 3**: Node-level chaos (drain, stress)
- **Week 4**: Full scenario (simulate real incident)

### Quarterly DR Drill (4 hours)
- Simulate complete AZ failure
- Simulate database primary failure
- Simulate full cloud failure (tabletop)
- Validate RTO/RPO targets

---

## Hypothesis Template

```
HYPOTHESIS: When [failure condition], the system will [expected behavior]
because [resilience mechanism].

STEADY STATE: [Metric] is [value] (e.g., error rate < 0.1%)

EXPERIMENT: [What we will do]

EXPECTED OUTCOME: [What should happen]

ACTUAL OUTCOME: [What happened]

VERDICT: Pass / Fail

ACTION ITEMS: [If failed, what to fix]
```

### Example Hypothesis
```
HYPOTHESIS: When 33% of product-service pods are deleted,
the service will maintain < 0.1% error rate because
HPA will replace pods within 30 seconds and remaining
pods can handle the load.

STEADY STATE: Error rate < 0.1%, P99 < 500ms

EXPERIMENT: Delete 33% of product-service pods

EXPECTED OUTCOME: Brief spike in latency, no errors,
pods replaced within 30s

ACTUAL OUTCOME: [Fill after experiment]

VERDICT: [Pass/Fail]
```

---

## Results Tracking

All experiment results are stored in:
- **Grafana**: Chaos dashboard with historical results
- **GitHub**: `chaos-engineering/results/` directory
- **Jira**: Chaos experiment tickets with outcomes

---

## Related Documents
- [Chaos Experiments](experiments/)
- [SLIs/SLOs](../docs/sre/slis-slos-slas.md)
- [Incident Management](../docs/sre/incident-management.md)
- [Disaster Recovery](../docs/architecture/disaster-recovery.md)
