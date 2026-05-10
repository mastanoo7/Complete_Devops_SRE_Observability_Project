# Runbook: Pod CrashLoopBackOff

**Severity**: P2–P3 | **Team**: Platform SRE | **Last Updated**: 2024-01

---

## Alert
```
Alert: PodCrashLooping
Condition: rate(kube_pod_container_status_restarts_total[15m]) * 60 > 0
Namespace: nexacommerce-prod
```

---

## Symptoms
- Pod status shows `CrashLoopBackOff`
- Pod restart count increasing rapidly
- Service may be partially or fully unavailable
- PagerDuty alert fires

---

## Impact Assessment

```bash
# Check which pods are crash looping
kubectl get pods -n nexacommerce-prod | grep -E "CrashLoop|Error|OOMKilled"

# Check restart counts
kubectl get pods -n nexacommerce-prod \
  -o custom-columns='NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,STATUS:.status.phase' \
  | sort -k2 -rn | head -20

# Check if HPA has enough replicas
kubectl get hpa -n nexacommerce-prod
```

---

## Diagnosis Steps

### Step 1: Get Pod Logs

```bash
# Get logs from crashing pod (current)
kubectl logs <pod-name> -n nexacommerce-prod --tail=100

# Get logs from previous crashed container
kubectl logs <pod-name> -n nexacommerce-prod --previous --tail=100

# Get logs with timestamps
kubectl logs <pod-name> -n nexacommerce-prod --timestamps=true --tail=200
```

### Step 2: Describe Pod for Events

```bash
kubectl describe pod <pod-name> -n nexacommerce-prod

# Look for:
# - OOMKilled (memory limit exceeded)
# - Exit code 1 (application error)
# - Exit code 137 (OOM kill)
# - Liveness probe failures
# - Image pull errors
```

### Step 3: Check Exit Code

| Exit Code | Meaning | Action |
|-----------|---------|--------|
| 0 | Success (unexpected exit) | Check application logic |
| 1 | Application error | Check application logs |
| 137 | OOMKilled | Increase memory limits |
| 139 | Segfault | Check for memory corruption |
| 143 | SIGTERM | Check graceful shutdown |

### Step 4: Common Root Causes

#### OOMKilled
```bash
# Verify OOM kill
kubectl describe pod <pod-name> -n nexacommerce-prod | grep -A5 "OOMKilled"

# Check current memory usage
kubectl top pod <pod-name> -n nexacommerce-prod

# Temporary fix: increase memory limit
kubectl patch deployment <deployment-name> -n nexacommerce-prod \
  --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"2Gi"}]'
```

#### Configuration Error
```bash
# Check if ConfigMap/Secret exists
kubectl get configmap <config-name> -n nexacommerce-prod
kubectl get secret <secret-name> -n nexacommerce-prod

# Check environment variables
kubectl exec <pod-name> -n nexacommerce-prod -- env | grep -v PASSWORD
```

#### Database Connection Failure
```bash
# Test DB connectivity from pod
kubectl exec <pod-name> -n nexacommerce-prod -- \
  nc -zv aurora-writer.nexacommerce.internal 5432

# Check Vault secret injection
kubectl logs <pod-name> -n nexacommerce-prod -c vault-agent
```

#### Image Pull Error
```bash
# Check image exists in ECR
aws ecr describe-images \
  --repository-name nexacommerce/<service-name> \
  --image-ids imageTag=<tag>

# Check ECR credentials
kubectl get secret ecr-credentials -n nexacommerce-prod
```

#### Liveness Probe Failure
```bash
# Test health endpoint manually
kubectl exec <pod-name> -n nexacommerce-prod -- \
  curl -s localhost:8080/health/live

# Temporarily disable liveness probe (EMERGENCY ONLY)
kubectl patch deployment <deployment-name> -n nexacommerce-prod \
  --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/containers/0/livenessProbe"}]'
```

---

## Remediation

### Option 1: Rollback Deployment
```bash
# Check rollout history
kubectl rollout history deployment/<deployment-name> -n nexacommerce-prod

# Rollback to previous version
kubectl rollout undo deployment/<deployment-name> -n nexacommerce-prod

# Rollback to specific revision
kubectl rollout undo deployment/<deployment-name> -n nexacommerce-prod --to-revision=3

# Monitor rollback
kubectl rollout status deployment/<deployment-name> -n nexacommerce-prod
```

### Option 2: Scale Down Crashing Pods
```bash
# If only some pods are crashing, delete them to force reschedule
kubectl delete pod <pod-name> -n nexacommerce-prod

# If all pods crashing, scale to 0 then back up
kubectl scale deployment/<deployment-name> --replicas=0 -n nexacommerce-prod
sleep 10
kubectl scale deployment/<deployment-name> --replicas=3 -n nexacommerce-prod
```

### Option 3: Force Redeploy
```bash
# Trigger rolling restart
kubectl rollout restart deployment/<deployment-name> -n nexacommerce-prod
```

---

## Verification

```bash
# Confirm pods are running
kubectl get pods -n nexacommerce-prod -l app=<service-name>

# Check restart count is stable
watch kubectl get pods -n nexacommerce-prod -l app=<service-name>

# Verify service health
kubectl exec -n nexacommerce-prod deploy/<service-name> -- \
  curl -s localhost:8080/health/ready | jq .

# Check error rate in Prometheus
# Query: sum(rate(http_requests_total{service="<service>",code=~"5.."}[5m]))
```

---

## Escalation
- If root cause unclear after 30 minutes → escalate to service owner
- If data corruption suspected → escalate to P1, notify DBA team
- If security-related crash → escalate to Security team immediately

---

## Post-Incident
1. Document root cause in incident ticket
2. Add monitoring/alerting if gap identified
3. Update this runbook if new scenario discovered
4. Consider adding startup probe if slow initialization
