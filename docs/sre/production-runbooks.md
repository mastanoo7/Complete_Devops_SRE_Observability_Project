# Production Runbooks — NexaCommerce

## Overview
This is the index of all production runbooks. Each runbook covers a specific failure scenario with step-by-step diagnosis and remediation procedures.

---

## Runbook Index

| Runbook | Alert | Severity | RTO |
|---------|-------|---------|-----|
| [Cluster Failure](../../runbooks/cluster-failure.md) | KubernetesClusterDown | P1 | < 15min |
| [Node Failure](../../runbooks/node-failure.md) | KubernetesNodeNotReady | P2 | < 5min |
| [Pod CrashLoop](../../runbooks/pod-crashloop.md) | PodCrashLooping | P2-P3 | < 10min |
| [High Latency](../../runbooks/high-latency.md) | LatencySLOBreach | P2-P3 | < 15min |
| [Database Failover](../../runbooks/database-failover.md) | AuroraFailure | P1 | < 5min |
| [Ingress Failure](../../runbooks/ingress-failure.md) | IngressFailure | P1-P2 | < 10min |
| [DNS Failure](../../runbooks/dns-failure.md) | DNSResolutionFailure | P1 | < 10min |

---

## On-Call Quick Reference

### First 5 Minutes of Any Incident

```bash
# 1. Check overall cluster health
kubectl get nodes
kubectl get pods -n nexacommerce-prod | grep -v Running

# 2. Check recent events
kubectl get events -n nexacommerce-prod \
  --sort-by='.lastTimestamp' | tail -20

# 3. Check error rate
# Grafana: https://grafana.nexacommerce.com/d/slo-overview

# 4. Check recent deployments
kubectl rollout history deployment -n nexacommerce-prod

# 5. Check logs for errors
kubectl logs -l app=auth-service -n nexacommerce-prod \
  --tail=50 | grep -E "ERROR|FATAL|panic"
```

### Common Quick Fixes

```bash
# Restart a crashing service
kubectl rollout restart deployment/<service> -n nexacommerce-prod

# Rollback last deployment
kubectl rollout undo deployment/<service> -n nexacommerce-prod

# Scale up a service
kubectl scale deployment/<service> --replicas=10 -n nexacommerce-prod

# Force pod deletion (stuck pods)
kubectl delete pod <pod-name> -n nexacommerce-prod --force --grace-period=0

# Clear stuck ArgoCD sync
argocd app terminate-op nexacommerce-prod
argocd app sync nexacommerce-prod --force
```

---

## Escalation Matrix

| Severity | Primary | Secondary | Manager | Executive |
|----------|---------|-----------|---------|-----------|
| P1 | On-call SRE | Senior SRE | Eng Manager | VP Eng (after 1h) |
| P2 | On-call SRE | Senior SRE | Eng Manager | — |
| P3 | On-call SRE | — | — | — |
| P4 | On-call SRE | — | — | — |

### Contact Information
- **PagerDuty**: https://nexacommerce.pagerduty.com
- **Slack**: #incidents (P1/P2), #platform-alerts (P3/P4)
- **Status Page**: https://status.nexacommerce.com
- **War Room**: https://meet.google.com/nexacommerce-war-room

---

## Useful Dashboards

| Dashboard | URL | Use Case |
|-----------|-----|---------|
| SLO Overview | https://grafana.nexacommerce.com/d/slo-overview | Overall health |
| Service Health | https://grafana.nexacommerce.com/d/service-health | Per-service metrics |
| Infrastructure | https://grafana.nexacommerce.com/d/infrastructure | Node/pod resources |
| Kubernetes | https://grafana.nexacommerce.com/d/kubernetes | Cluster health |
| Istio | https://grafana.nexacommerce.com/d/istio | Service mesh |
| Security | https://grafana.nexacommerce.com/d/security | Security events |

---

## Post-Incident Checklist

```bash
□ Incident resolved and verified
□ Status page updated to "Resolved"
□ Stakeholders notified
□ Incident ticket created in Jira
□ Post-mortem scheduled (within 48h)
□ Runbook updated if new steps discovered
□ Action items created
□ Error budget impact calculated
```

---

## Related Documents
- [Incident Management](incident-management.md)
- [Postmortem Template](postmortem-template.md)
- [SLIs/SLOs/SLAs](slis-slos-slas.md)
- [Alerting Strategy](alerting-strategy.md)
- [Error Budget](error-budget.md)
