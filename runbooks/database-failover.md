# Runbook: Database Failover

**Severity**: P1 | **Team**: Platform SRE + DBA | **Last Updated**: 2024-01

---

## Alert
```
Alert: AuroraHighConnections OR Aurora primary unreachable
RDS Event: RDS-EVENT-0006 (failover started)
CloudWatch: DatabaseConnections > 900
```

---

## Symptoms
- Services returning 500 errors with DB connection errors
- Aurora console shows "Failing over" status
- Connection pool exhaustion in application logs
- Increased latency on all DB-dependent services

---

## Aurora Failover Overview

```
Aurora Multi-AZ Cluster:
  Writer: aurora-writer.nexacommerce.internal (CNAME → current primary)
  Reader: aurora-reader.nexacommerce.internal (CNAME → read replicas)

Automatic failover: ~30 seconds
Manual failover: ~10 seconds
Global DB failover (cross-region): ~1 minute
```

---

## Diagnosis

```bash
# Check Aurora cluster status
aws rds describe-db-clusters \
  --db-cluster-identifier nexacommerce-prod-aurora \
  --query 'DBClusters[0].{Status:Status,Members:DBClusterMembers}' \
  --output table

# Check which instance is writer
aws rds describe-db-instances \
  --filters Name=db-cluster-id,Values=nexacommerce-prod-aurora \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Role:ReadReplicaSourceDBInstanceIdentifier,Status:DBInstanceStatus}' \
  --output table

# Check recent RDS events
aws rds describe-events \
  --source-identifier nexacommerce-prod-aurora \
  --source-type db-cluster \
  --duration 60 \
  --output table

# Check application connection errors
kubectl logs -l app=product-service -n nexacommerce-prod --tail=50 | \
  grep -E "connection|FATAL|ERROR"
```

---

## Automatic Failover (Aurora handles this)

Aurora automatically promotes a read replica when:
- Primary instance becomes unavailable
- AZ failure detected
- Manual failover triggered

**Expected timeline**: 30–60 seconds
**DNS update**: Aurora updates CNAME automatically

```bash
# Monitor failover progress
watch -n 5 'aws rds describe-db-clusters \
  --db-cluster-identifier nexacommerce-prod-aurora \
  --query "DBClusters[0].Status" --output text'

# Verify new writer endpoint resolves
nslookup aurora-writer.nexacommerce.internal
```

---

## Manual Failover (If Needed)

```bash
# Trigger manual failover to specific instance
aws rds failover-db-cluster \
  --db-cluster-identifier nexacommerce-prod-aurora \
  --target-db-instance-identifier nexacommerce-prod-aurora-reader-1

# Monitor failover
aws rds wait db-cluster-available \
  --db-cluster-identifier nexacommerce-prod-aurora
```

---

## Application Recovery

### Step 1: Restart Connection Pools

```bash
# Rolling restart to clear stale connections
kubectl rollout restart deployment/product-service -n nexacommerce-prod
kubectl rollout restart deployment/order-service -n nexacommerce-prod
kubectl rollout restart deployment/auth-service -n nexacommerce-prod
kubectl rollout restart deployment/payment-service -n nexacommerce-prod
kubectl rollout restart deployment/inventory-service -n nexacommerce-prod

# Monitor restarts
kubectl get pods -n nexacommerce-prod -w
```

### Step 2: Verify Connectivity

```bash
# Test DB connection from each service
for SVC in product-service order-service auth-service payment-service; do
  echo "Testing $SVC..."
  kubectl exec -n nexacommerce-prod deploy/$SVC -- \
    curl -s localhost:8080/actuator/health | jq .components.db
done
```

### Step 3: Check for Data Consistency

```bash
# Verify no transactions were lost (check application logs)
kubectl logs -n nexacommerce-prod deploy/order-service --tail=200 | \
  grep -E "transaction|rollback|commit"

# Check Aurora replication lag (should be 0 after failover)
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name AuroraReplicaLag \
  --dimensions Name=DBClusterIdentifier,Value=nexacommerce-prod-aurora \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Maximum
```

---

## Cross-Region Failover (Disaster Scenario)

If entire us-east-1 Aurora cluster is unavailable:

```bash
# Promote Aurora Global Database secondary (us-west-2)
aws rds failover-global-cluster \
  --global-cluster-identifier nexacommerce-global \
  --target-db-cluster-arn arn:aws:rds:us-west-2:ACCOUNT:cluster:nexacommerce-dr-aurora

# Update application connection strings to DR region
kubectl set env deployment/product-service \
  SPRING_DATASOURCE_URL="jdbc:postgresql://aurora-writer.nexacommerce-dr.internal:5432/product_db" \
  -n nexacommerce-prod

# Update Route53 to point to DR region
aws route53 change-resource-record-sets \
  --hosted-zone-id ZONE_ID \
  --change-batch file://scripts/dr/aurora-failover-dns.json
```

---

## Redis Failover

```bash
# Check Redis cluster status
aws elasticache describe-replication-groups \
  --replication-group-id nexacommerce-prod-redis \
  --query 'ReplicationGroups[0].{Status:Status,NodeGroups:NodeGroups}'

# Manual Redis failover
aws elasticache test-failover \
  --replication-group-id nexacommerce-prod-redis \
  --node-group-id 0001
```

---

## Verification

```bash
# Check all services healthy
kubectl get pods -n nexacommerce-prod
kubectl exec -n nexacommerce-prod deploy/product-service -- \
  curl -s localhost:8082/actuator/health | jq .

# Check error rate returning to normal
# Grafana: https://grafana.nexacommerce.com/d/slo-overview

# Verify order processing resumed
kubectl logs -n nexacommerce-prod deploy/order-service --tail=20 | \
  grep "Order created"
```

---

## Post-Incident
1. Review Aurora failover logs in RDS console
2. Check if connection pool settings need tuning
3. Verify application retry logic worked correctly
4. Update DR runbook if new steps discovered
5. Test failover in staging quarterly
