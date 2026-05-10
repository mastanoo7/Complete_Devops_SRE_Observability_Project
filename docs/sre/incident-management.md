# Incident Management — NexaCommerce

## Overview
This document defines the incident management process for NexaCommerce production systems, including severity levels, escalation paths, communication templates, and post-incident review procedures.

---

## Incident Severity Levels

| Severity | Definition | Response Time | Resolution Target | Examples |
|----------|-----------|---------------|-------------------|---------|
| **P1 — Critical** | Complete service outage, data loss, security breach | 5 minutes | 1 hour | Payment service down, auth failure for all users, data breach |
| **P2 — High** | Major feature unavailable, >10% users affected | 15 minutes | 4 hours | Checkout broken, search down, >5% error rate |
| **P3 — Medium** | Degraded performance, <10% users affected | 30 minutes | 24 hours | Slow product pages, notification delays |
| **P4 — Low** | Minor issue, no user impact | 2 hours | 72 hours | Dashboard cosmetic issue, non-critical alert |

---

## On-Call Rotation

### Primary On-Call Responsibilities
- Acknowledge PagerDuty alerts within **5 minutes**
- Assess severity and escalate if needed
- Lead incident response
- Update status page every 15 minutes during P1/P2

### Escalation Path
```
Alert fires
    ↓ 5 min
Primary On-Call (Engineer)
    ↓ 15 min (no ack)
Secondary On-Call (Senior Engineer)
    ↓ 30 min (no resolution)
Engineering Manager
    ↓ 1 hour (P1 only)
VP Engineering + CTO
```

---

## Incident Response Process

### Phase 1: Detection & Triage (0-15 min)

```bash
# 1. Acknowledge PagerDuty alert
# 2. Join incident Slack channel: #incident-YYYY-MM-DD-NNN
# 3. Assess severity using criteria above
# 4. Declare incident in PagerDuty

# Quick triage commands:
kubectl get pods -n nexacommerce-prod --field-selector=status.phase!=Running
kubectl top nodes
kubectl get events -n nexacommerce-prod --sort-by='.lastTimestamp' | tail -20

# Check error rates in Grafana:
# https://grafana.nexacommerce.com/d/slo-overview
```

### Phase 2: Incident Declaration

For P1/P2, immediately:
1. Post in `#incidents` Slack channel
2. Update status page: https://status.nexacommerce.com
3. Assign Incident Commander (IC) and Communications Lead

**Incident Slack Template:**
```
🚨 INCIDENT DECLARED — P[1/2]
Title: [Brief description]
Impact: [What's broken, how many users affected]
Started: [Time]
IC: @[name]
Comms: @[name]
Bridge: [Zoom/Meet link]
Tracking: [Jira/Linear ticket]
```

### Phase 3: Investigation & Mitigation

```bash
# Check recent deployments
kubectl rollout history deployment -n nexacommerce-prod

# Check pod logs for errors
kubectl logs -l app=payment-service -n nexacommerce-prod --tail=100 | grep ERROR

# Check Istio traffic
kubectl exec -n istio-system deploy/istiod -- \
  pilot-discovery request GET /debug/endpointz

# Check database connections
kubectl exec -n nexacommerce-prod deploy/product-service -- \
  curl -s localhost:8082/actuator/health | jq .

# Rollback if deployment caused issue
kubectl rollout undo deployment/payment-service -n nexacommerce-prod

# Scale up if capacity issue
kubectl scale deployment/product-service --replicas=10 -n nexacommerce-prod
```

### Phase 4: Resolution & Recovery

1. Confirm metrics returning to normal
2. Verify SLO compliance restored
3. Update status page: "Resolved"
4. Send resolution notification to stakeholders
5. Schedule post-mortem within 48 hours

### Phase 5: Post-Incident Review

**Timeline**: Within 48 hours of resolution
**Attendees**: IC, all responders, affected team leads
**Output**: Post-mortem document (see [template](postmortem-template.md))

---

## Communication Templates

### Status Page Updates

**Investigating:**
```
We are investigating reports of [issue description].
Our team has been alerted and is actively investigating.
Next update in 15 minutes.
```

**Identified:**
```
We have identified the cause of [issue description]: [root cause].
We are implementing a fix. Estimated resolution: [time].
Next update in 15 minutes.
```

**Resolved:**
```
This incident has been resolved. [Brief description of fix].
All systems are operating normally.
We will publish a post-mortem within 48 hours.
```

---

## Runbook Index

| Runbook | Trigger | Link |
|---------|---------|------|
| Cluster Failure | K8s cluster unreachable | [cluster-failure.md](../../runbooks/cluster-failure.md) |
| Node Failure | Node NotReady | [node-failure.md](../../runbooks/node-failure.md) |
| Pod CrashLoop | Pod restart count > 5 | [pod-crashloop.md](../../runbooks/pod-crashloop.md) |
| High Latency | P99 > SLO threshold | [high-latency.md](../../runbooks/high-latency.md) |
| Database Failover | Aurora primary failure | [database-failover.md](../../runbooks/database-failover.md) |
| Ingress Failure | 502/504 from ALB | [ingress-failure.md](../../runbooks/ingress-failure.md) |
| DNS Failure | DNS resolution failing | [dns-failure.md](../../runbooks/dns-failure.md) |

---

## Incident Metrics (Track Monthly)

| Metric | Target | Measurement |
|--------|--------|-------------|
| MTTD (Mean Time to Detect) | < 5 min | Alert fire → acknowledgment |
| MTTR (Mean Time to Resolve) | P1 < 1h, P2 < 4h | Declaration → resolution |
| Incident frequency | < 2 P1/month | Count per month |
| Post-mortem completion | 100% within 48h | % completed on time |
| Action item completion | > 80% within 30d | % closed |
