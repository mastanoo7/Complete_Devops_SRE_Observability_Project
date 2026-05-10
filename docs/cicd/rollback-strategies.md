# Rollback Strategies — NexaCommerce

## Overview
Every deployment must have a tested rollback plan. This document covers rollback procedures for applications, databases, and infrastructure.

---

## Application Rollback

### Automatic Rollback (Argo Rollouts)

Triggered automatically when canary analysis fails:

```yaml
# Conditions that trigger auto-rollback:
- error_rate > 1% for 5 minutes
- p99_latency > 500ms for 5 minutes
- pod_restart_count > 0 during rollout
```

```bash
# Monitor rollout status
kubectl argo rollouts get rollout product-service \
  -n nexacommerce-prod --watch

# Manual abort (triggers rollback)
kubectl argo rollouts abort product-service -n nexacommerce-prod
```

### Manual Rollback via ArgoCD

```bash
# List revision history
argocd app history nexacommerce-prod

# Rollback to previous revision
argocd app rollback nexacommerce-prod

# Rollback to specific revision
argocd app rollback nexacommerce-prod --revision 42
```

### Manual Rollback via kubectl

```bash
# Check rollout history
kubectl rollout history deployment/product-service -n nexacommerce-prod

# Rollback to previous version
kubectl rollout undo deployment/product-service -n nexacommerce-prod

# Rollback to specific revision
kubectl rollout undo deployment/product-service \
  --to-revision=3 -n nexacommerce-prod

# Monitor rollback progress
kubectl rollout status deployment/product-service -n nexacommerce-prod
```

### Image Tag Rollback

```bash
# Set specific image tag
kubectl set image deployment/product-service \
  product-service=$REGISTRY/nexacommerce/product-service:sha-abc123 \
  -n nexacommerce-prod

# Verify rollback
kubectl get pods -n nexacommerce-prod -l app=product-service \
  -o jsonpath='{.items[*].spec.containers[0].image}'
```

---

## Database Rollback

### Application-Level (Flyway/Alembic)

```bash
# Java services (Flyway)
cd backend/product-service
mvn flyway:undo -Dflyway.target=V5

# Python services (Alembic)
cd backend/inventory-service
alembic downgrade -1

# Go services (golang-migrate)
cd backend/auth-service
migrate -path db/migrations -database $DATABASE_URL down 1
```

### Aurora Point-in-Time Recovery

```bash
# Restore Aurora to specific point in time
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier nexacommerce-prod-aurora \
  --db-cluster-identifier nexacommerce-prod-aurora-restored \
  --restore-to-time 2024-01-15T10:30:00Z \
  --vpc-security-group-ids sg-xxxxxxxx \
  --db-subnet-group-name nexacommerce-prod-db-subnet-group

# Wait for restore
aws rds wait db-cluster-available \
  --db-cluster-identifier nexacommerce-prod-aurora-restored
```

---

## Infrastructure Rollback (Terraform)

```bash
# View state history
terraform state list

# Rollback to previous state (using S3 versioning)
aws s3api list-object-versions \
  --bucket nexacommerce-tf-state \
  --prefix prod/terraform.tfstate

# Restore specific version
aws s3api get-object \
  --bucket nexacommerce-tf-state \
  --key prod/terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate.backup

# Apply previous state
terraform apply -state=terraform.tfstate.backup
```

---

## Rollback Decision Matrix

| Scenario | Rollback Type | Time | Procedure |
|----------|--------------|------|-----------|
| New deployment causes errors | App rollback | < 5 min | ArgoCD rollback |
| Database migration fails | DB rollback | 15-30 min | Flyway undo |
| Infrastructure change breaks cluster | TF rollback | 30-60 min | Terraform state restore |
| Data corruption | PITR restore | 1-2 hours | Aurora PITR |
| Full environment failure | DR failover | 15-60 min | Multi-cloud failover |

---

## Post-Rollback Checklist

```bash
□ Verify rollback completed successfully
□ Check error rate returned to baseline
□ Check P99 latency returned to baseline
□ Verify all pods are Running and Ready
□ Run smoke tests
□ Update status page
□ Notify stakeholders
□ Create incident ticket
□ Schedule post-mortem
```
