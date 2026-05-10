# Disaster Recovery Strategy — NexaCommerce

## Overview
NexaCommerce implements a **multi-cloud active-active** architecture that provides built-in disaster recovery. This document covers DR scenarios, RTO/RPO targets, failover procedures, and testing schedules.

---

## DR Architecture

```
Normal Operations (Active-Active):
  AWS us-east-1    → 40% traffic (Primary)
  Azure westeurope → 35% traffic (Secondary)
  GCP us-central1  → 25% traffic (Tertiary)

Failover Scenarios:
  Single AZ failure  → Automatic (< 30s)
  Single Region fail → Automatic (< 5min)
  Full Cloud failure → Semi-automatic (< 15min)
  Full DR (all clouds) → Manual (< 1 hour)
```

---

## RTO and RPO Targets

| Scenario | RTO | RPO | Automation |
|----------|-----|-----|-----------|
| Single AZ failure | < 30s | 0 | Fully automatic |
| Single region failure | < 5min | < 1s | Fully automatic |
| Full cloud failure | < 15min | < 30s | Semi-automatic |
| Database primary failure | < 60s | < 5s | Fully automatic |
| Redis failure | < 30s | Acceptable loss | Fully automatic |
| Full platform DR | < 1 hour | < 5min | Manual with runbook |

---

## Data Replication Strategy

### Database Replication

```
Aurora PostgreSQL (AWS):
  Primary: us-east-1 (writer)
  Replicas: us-east-1 (2 readers, multi-AZ)
  Global DB: us-west-2 (DR replica, RPO < 1s)

CosmosDB (Azure):
  Multi-region write: westeurope + eastus2
  Consistency: Session (default), Strong (payments)
  Automatic failover: enabled

Cloud Spanner (GCP):
  Multi-region: us-central1 + us-east1
  RPO: 0 (synchronous replication)
  RTO: < 1min (automatic)
```

### Cross-Cloud Data Sync

```
Debezium CDC → Kafka → Cross-cloud consumers
  AWS Aurora → Kafka MirrorMaker 2 → Azure Event Hubs → CosmosDB
  AWS Aurora → Kafka MirrorMaker 2 → GCP Pub/Sub → Cloud Spanner

Replication lag target: < 1 second
Monitoring: Kafka consumer lag alerts
```

---

## Failover Procedures

### Scenario 1: AWS Region Failure

**Detection**: CloudFlare health check fails for us-east-1 ALB

**Automatic Actions** (< 30 seconds):
1. CloudFlare detects health check failure
2. DNS TTL: 30 seconds
3. Traffic redistributed: Azure 60%, GCP 40%
4. PagerDuty alert fires

**Manual Verification**:
```bash
# Verify CloudFlare routing
curl -H "Host: api.nexacommerce.com" \
  https://api.nexacommerce.com/health \
  -v 2>&1 | grep "< HTTP"

# Check traffic distribution
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=nexacommerce-prod \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 --statistics Sum

# Verify Azure AKS handling traffic
kubectl --context=aks-westeurope get pods -n nexacommerce-prod
```

### Scenario 2: Database Primary Failure

**Detection**: Aurora health check fails, CloudWatch alarm fires

**Automatic Actions** (< 60 seconds):
1. Aurora detects primary failure
2. Promotes read replica to writer
3. Updates CNAME: `aurora-writer.nexacommerce.internal`
4. Applications reconnect automatically (connection pool retry)

**Manual Steps if Auto-Failover Fails**:
```bash
# Force manual failover
aws rds failover-db-cluster \
  --db-cluster-identifier nexacommerce-prod-aurora

# Monitor failover
watch -n 5 'aws rds describe-db-clusters \
  --db-cluster-identifier nexacommerce-prod-aurora \
  --query "DBClusters[0].Status" --output text'

# Restart application connection pools
kubectl rollout restart deployment -n nexacommerce-prod
```

### Scenario 3: Full Cloud Outage (Extreme)

**Trigger**: Both AWS and Azure simultaneously unavailable

**Manual Steps**:
```bash
# 1. Verify GCP is healthy
kubectl --context=gke-us-central1 get nodes
kubectl --context=gke-us-central1 get pods -n nexacommerce-prod

# 2. Scale up GCP cluster to handle 100% traffic
kubectl --context=gke-us-central1 \
  scale deployment --all --replicas=10 -n nexacommerce-prod

# 3. Update CloudFlare to route 100% to GCP
# Via CloudFlare API or dashboard

# 4. Promote Cloud Spanner as primary DB
# (Already active, no action needed)

# 5. Update DNS TTL to 30s for faster recovery
# Via CloudFlare dashboard

# 6. Notify stakeholders
bash scripts/dr/notify-stakeholders.sh \
  --severity critical \
  --message "Full DR activated — GCP only"
```

---

## DR Testing Schedule

| Test Type | Frequency | Duration | Scope |
|-----------|-----------|----------|-------|
| AZ failover drill | Monthly | 30 min | Single AZ |
| Region failover drill | Quarterly | 2 hours | Full region |
| Database failover drill | Monthly | 1 hour | Aurora failover |
| Full DR drill | Annually | 4 hours | Complete DR |
| Chaos engineering | Weekly | 1 hour | Random experiments |

### DR Test Checklist

```bash
# Pre-test
□ Notify stakeholders (24h advance)
□ Verify monitoring is active
□ Confirm rollback plan
□ Check error budget remaining

# During test
□ Document all actions with timestamps
□ Monitor SLO dashboards
□ Verify automatic failover triggers
□ Test manual failover procedures

# Post-test
□ Verify full recovery
□ Document RTO/RPO achieved
□ Update runbooks with findings
□ Schedule follow-up for action items
```

---

## Backup Strategy

### Database Backups

| Database | Backup Type | Frequency | Retention | Location |
|----------|------------|-----------|-----------|---------|
| Aurora PostgreSQL | Automated snapshots | Daily | 35 days | S3 (same region) |
| Aurora PostgreSQL | Manual snapshots | Weekly | 1 year | S3 (cross-region) |
| Aurora PostgreSQL | PITR | Continuous | 35 days | Aurora managed |
| CosmosDB | Continuous backup | Continuous | 30 days | Azure managed |
| Cloud Spanner | Managed backups | Daily | 30 days | GCP managed |

### Object Storage Backups

```bash
# S3 cross-region replication (configured in Terraform)
# nexacommerce-assets-prod → nexacommerce-assets-dr (us-west-2)
# Replication lag: < 15 minutes
# Versioning: enabled

# Verify replication status
aws s3api get-bucket-replication \
  --bucket nexacommerce-assets-prod
```

---

## Communication Plan

### Internal Escalation
1. On-call engineer → Slack #incidents
2. Engineering Manager → Phone/SMS
3. VP Engineering → Phone/SMS (P1 only)
4. CTO → Phone/SMS (full DR only)

### External Communication
1. Status page update: https://status.nexacommerce.com
2. Enterprise customer notification: < 15 min for P1
3. Press release: Only if > 4 hours downtime

---

## Related Documents
- [Disaster Recovery Diagram](../diagrams/disaster-recovery.mmd)
- [Database Failover Runbook](../../runbooks/database-failover.md)
- [Cluster Failure Runbook](../../runbooks/cluster-failure.md)
- [Multi-Region Design](multi-region-design.md)
