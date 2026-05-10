# Runtime Security — NexaCommerce

## Overview
Runtime security detects and responds to threats in running containers and Kubernetes workloads using Falco, OPA Gatekeeper, and Kyverno.

---

## Falco — Runtime Threat Detection

Falco monitors system calls at the kernel level to detect anomalous behavior.

### Key Detection Scenarios

| Scenario | Rule | Severity |
|----------|------|---------|
| Shell in container | Shell Spawned in Container | Critical |
| Package manager executed | Package Manager in Container | Error |
| Unexpected outbound connection | Unexpected Outbound (payment) | Critical |
| Sensitive file access | Sensitive File Access | Critical |
| Privilege escalation | Privilege Escalation Attempt | Critical |
| Crypto mining | Crypto Mining Activity | Critical |
| Container escape | Container Escape via /proc | Critical |
| kubectl in container | kubectl Executed in Container | Warning |

### Falco Response Actions

```yaml
# Falco Sidekick routes alerts to:
outputs:
  slack:
    webhookurl: https://hooks.slack.com/...
    channel: "#security-alerts"
    minimumpriority: warning

  pagerduty:
    routingkey: <routing-key>
    minimumpriority: critical

  elasticsearch:
    hostport: http://elasticsearch:9200
    index: falco-alerts
    minimumpriority: debug
```

---

## Kyverno — Admission Control

Kyverno enforces policies at admission time (before pods start).

### Policy Summary

| Policy | Action | Scope |
|--------|--------|-------|
| require-signed-images | Enforce | prod, staging |
| disallow-latest-tag | Enforce | prod |
| require-resource-limits | Enforce | prod, staging |
| disallow-privileged | Enforce | prod, staging |
| require-non-root | Enforce | prod |
| require-readonly-rootfs | Enforce | prod |
| disallow-host-namespaces | Enforce | prod, staging |
| require-pod-probes | Audit | prod |
| require-labels | Audit | prod |
| restrict-registries | Enforce | prod |

### Testing Policies

```bash
# Test policy against a manifest (dry-run)
kubectl apply --dry-run=server -f kubernetes/base/auth-service/deployment.yaml

# Check policy violations
kubectl get policyreport -n nexacommerce-prod

# View specific violation
kubectl describe policyreport -n nexacommerce-prod
```

---

## OPA Gatekeeper — Constraint Enforcement

OPA Gatekeeper provides additional policy enforcement via ConstraintTemplates.

### Active Constraints

| Constraint | Enforcement | Purpose |
|-----------|-------------|---------|
| K8sBlockNodePort | Deny | No NodePort in prod |
| K8sRequiredLabels | Warn | Require standard labels |
| K8sContainerLimits | Deny | Max CPU/memory limits |
| K8sAllowedRepos | Deny | Only approved registries |

---

## Network Security

### mTLS Enforcement (Istio)

```bash
# Verify mTLS is enforced
kubectl exec -n nexacommerce-prod deploy/auth-service -c istio-proxy -- \
  pilot-agent request GET config_dump | \
  jq '.configs[] | select(.["@type"] | contains("Listener")) | .dynamic_listeners[].active_state.listener.filter_chains[].transport_socket'

# Check PeerAuthentication
kubectl get peerauthentication -n nexacommerce-prod
```

### Network Policy Verification

```bash
# Test that default-deny is working
kubectl run test-pod --image=busybox --rm -it --restart=Never \
  -n nexacommerce-prod -- wget -qO- http://payment-service
# Should fail (connection refused)

# Test allowed connection
kubectl exec -n nexacommerce-prod deploy/order-service -- \
  curl -s http://payment-service/health/ready
# Should succeed
```

---

## Security Monitoring

### Key Security Metrics

```promql
# Falco critical alerts per hour
sum(increase(falco_events_total{priority="Critical"}[1h]))

# Failed authentication attempts
sum(rate(auth_login_failures_total[5m]))

# Kyverno policy violations
sum(kyverno_policy_results_total{result="fail"})
```

### Security Dashboard

Access: https://grafana.nexacommerce.com/d/security

Panels:
- Falco alerts by severity (last 24h)
- Top Falco rule triggers
- Failed auth attempts
- Kyverno violations
- Network policy denies

---

## Incident Response (Security)

### Security Incident Severity

| Severity | Examples | Response |
|----------|---------|---------|
| P1 | Data breach, active intrusion | Immediate isolation + escalation |
| P2 | Malware detected, credential compromise | Contain within 1 hour |
| P3 | Policy violation, suspicious activity | Investigate within 4 hours |

### Containment Procedures

```bash
# Isolate compromised pod immediately
kubectl label pod <pod-name> -n nexacommerce-prod \
  security.nexacommerce.io/quarantine=true

# Apply quarantine network policy
kubectl apply -f security/policies/quarantine-policy.yaml

# Capture pod forensics before deletion
kubectl exec <pod-name> -- ps aux > forensics/processes.txt
kubectl exec <pod-name> -- netstat -an > forensics/connections.txt
kubectl logs <pod-name> > forensics/logs.txt

# Delete compromised pod
kubectl delete pod <pod-name> -n nexacommerce-prod --force
```

---

## Related Documents
- [Falco Rules](../../security/falco/falco-rules.yaml)
- [Kyverno Policies](../../security/kyverno/policies.yaml)
- [OPA Constraints](../../security/opa/gatekeeper-constraints.yaml)
- [Security Architecture](../architecture/security-architecture.md)
