# Deployment Strategies — NexaCommerce

## Overview
NexaCommerce uses **three deployment strategies** depending on the risk level and service criticality.

---

## Strategy 1: Canary Deployment (Default for Production)

Used for: All production deployments

```
Traffic split:
  5% → new version (canary)
  95% → old version (stable)
  
  Monitor 10 minutes
  ↓ (if metrics green)
  
  25% → new version
  75% → old version
  
  Monitor 10 minutes
  ↓ (if metrics green)
  
  100% → new version
  Old version terminated
```

### Implementation (Argo Rollouts)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: product-service
spec:
  strategy:
    canary:
      steps:
        - setWeight: 5
        - pause: {duration: 10m}
        - setWeight: 25
        - pause: {duration: 10m}
        - setWeight: 100
      analysis:
        templates:
          - templateName: success-rate
        startingStep: 1
        args:
          - name: service-name
            value: product-service
```

### Canary Analysis Metrics
```yaml
# Auto-rollback if:
error_rate > 1%          # 5xx responses
p99_latency > 500ms      # Response time
pod_restart_rate > 0     # Any pod restarts
```

---

## Strategy 2: Blue/Green Deployment (AWS Primary)

Used for: Major releases, database migrations

```
Blue (current):  100% traffic
Green (new):     0% traffic, deployed and tested

Switch:
  Blue: 0% traffic
  Green: 100% traffic
  
  Blue kept for 30 minutes (instant rollback available)
  Blue terminated after validation
```

### Implementation

```bash
# Deploy green environment
kubectl apply -k kubernetes/overlays/prod-green/

# Switch traffic (update Kong route)
kubectl patch ingress nexacommerce-ingress \
  -p '{"spec":{"rules":[{"host":"api.nexacommerce.com","http":{"paths":[{"backend":{"service":{"name":"product-service-green"}}}]}}]}}'

# Verify green is healthy
kubectl rollout status deployment/product-service-green -n nexacommerce-prod

# Remove blue after validation
kubectl delete deployment product-service-blue -n nexacommerce-prod
```

---

## Strategy 3: Rolling Update (Dev/Staging)

Used for: Development and staging environments

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 25%        # Max extra pods during update
    maxUnavailable: 0    # Never reduce below desired count
```

---

## Zero-Downtime Requirements

All deployments must satisfy:

| Requirement | Implementation |
|-------------|---------------|
| No dropped requests | `maxUnavailable: 0` |
| Graceful shutdown | `terminationGracePeriodSeconds: 60` |
| Health checks pass before traffic | Readiness probe |
| PDB respected | `minAvailable: 2` |
| Connection draining | Istio `drainDuration: 45s` |

### Graceful Shutdown Pattern

```go
// All services implement graceful shutdown
func main() {
    srv := &http.Server{Addr: ":8080"}
    
    go srv.ListenAndServe()
    
    // Wait for SIGTERM
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGTERM)
    <-quit
    
    // Give in-flight requests 30s to complete
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()
    srv.Shutdown(ctx)
}
```

---

## Database Migration Strategy

```
1. Backward-compatible migration first (add column, don't remove)
2. Deploy new application version
3. Verify new version works with old schema
4. Run migration (add constraints, remove old columns)
5. Verify migration succeeded

Tools: Flyway (Java), Alembic (Python), golang-migrate (Go)
```

---

## Rollback Procedures

See [Rollback Strategies](rollback-strategies.md) for detailed procedures.

Quick rollback:
```bash
# ArgoCD rollback
argocd app rollback nexacommerce-prod

# Kubectl rollback
kubectl rollout undo deployment/product-service -n nexacommerce-prod

# Image tag rollback
kubectl set image deployment/product-service \
  product-service=REGISTRY/nexacommerce/product-service:PREVIOUS_TAG \
  -n nexacommerce-prod
```
