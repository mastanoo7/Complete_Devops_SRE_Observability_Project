# Runbook: Kubernetes Cluster Failure

**Severity**: P1 | **Team**: Platform SRE | **Last Updated**: 2024-01

---

## Alert
```
Alert: KubernetesClusterDown
Condition: kube_node_status_condition{condition="Ready",status="true"} == 0
Or: API server unreachable
```

---

## Symptoms
- All pods in cluster showing as Unknown/Pending
- kubectl commands timing out or failing
- All services returning 502/503
- CloudFlare health checks failing for entire cluster

---

## Immediate Actions (First 5 Minutes)

```bash
# 1. Verify cluster is actually down (not just your kubeconfig)
kubectl --context=nexacommerce-prod get nodes --timeout=10s

# 2. Check from multiple locations/machines
curl -k https://eks-prod.us-east-1.eks.amazonaws.com/healthz

# 3. Check AWS console for EKS cluster status
aws eks describe-cluster \
  --name nexacommerce-prod \
  --query 'cluster.{Status:status,Health:health}' \
  --output table

# 4. Declare P1 incident immediately
# Post in #incidents Slack channel
```

---

## Diagnosis

### Check EKS Control Plane

```bash
# Check EKS cluster health
aws eks describe-cluster \
  --name nexacommerce-prod \
  --region us-east-1 \
  --query 'cluster.health'

# Check EKS API server logs
aws logs filter-log-events \
  --log-group-name /aws/eks/nexacommerce-prod/cluster \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '30 minutes ago' +%s000)

# Check node group status
aws eks describe-nodegroup \
  --cluster-name nexacommerce-prod \
  --nodegroup-name app-general \
  --query 'nodegroup.{Status:status,Health:health}'
```

### Check Node Status

```bash
# List all nodes and their status
kubectl get nodes -o wide

# Check node conditions
kubectl describe nodes | grep -A5 "Conditions:"

# Check if nodes are in AWS console
aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/nexacommerce-prod,Values=owned" \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,State:State.Name,AZ:Placement.AvailabilityZone}' \
  --output table
```

### Check etcd Health

```bash
# For managed EKS, etcd is AWS-managed
# Check via EKS API server health
curl -k https://$(aws eks describe-cluster \
  --name nexacommerce-prod \
  --query 'cluster.endpoint' \
  --output text)/healthz

# Check EKS control plane metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EKS \
  --metric-name cluster_failed_node_count \
  --dimensions Name=ClusterName,Value=nexacommerce-prod \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 --statistics Maximum
```

---

## Remediation

### Option 1: Node Group Refresh (Most Common Fix)

```bash
# If nodes are unhealthy, trigger node group update
aws eks update-nodegroup-config \
  --cluster-name nexacommerce-prod \
  --nodegroup-name app-general \
  --scaling-config minSize=3,maxSize=30,desiredSize=6

# Force node group refresh
aws ec2 terminate-instances \
  --instance-ids $(aws ec2 describe-instances \
    --filters "Name=tag:kubernetes.io/cluster/nexacommerce-prod,Values=owned" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text | head -3)
```

### Option 2: Cluster Autoscaler Recovery

```bash
# Check if cluster autoscaler is stuck
kubectl logs -n kube-system deploy/cluster-autoscaler --tail=50

# Restart cluster autoscaler
kubectl rollout restart deploy/cluster-autoscaler -n kube-system
```

### Option 3: Failover to Secondary Cluster

```bash
# If primary cluster is unrecoverable, activate secondary
# Update CloudFlare to route 100% to Azure AKS

# Scale up Azure AKS
kubectl --context=aks-westeurope \
  scale deployment --all --replicas=5 -n nexacommerce-prod

# Verify Azure cluster is healthy
kubectl --context=aks-westeurope get pods -n nexacommerce-prod

# Update CloudFlare routing (via API or dashboard)
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/load_balancers/${LB_ID}" \
  -H "Authorization: Bearer ${CF_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"default_pools":["azure-westeurope-pool"]}'
```

### Option 4: Restore from Velero Backup

```bash
# List available backups
velero backup get

# Restore cluster state from latest backup
velero restore create \
  --from-backup nexacommerce-prod-$(date +%Y%m%d) \
  --include-namespaces nexacommerce-prod \
  --wait

# Verify restore
kubectl get pods -n nexacommerce-prod
```

---

## Verification

```bash
# All nodes ready
kubectl get nodes | grep -v Ready

# All pods running
kubectl get pods -n nexacommerce-prod | grep -v Running

# Services responding
for SVC in auth-service product-service order-service payment-service; do
  echo -n "$SVC: "
  kubectl exec -n nexacommerce-prod deploy/$SVC -- \
    curl -s localhost:8080/health/ready | jq -r .status
done

# Check error rate returning to normal
# Grafana: https://grafana.nexacommerce.com/d/slo-overview
```

---

## Post-Incident
1. Capture EKS control plane logs before they expire
2. Review node group health history
3. Check if Cluster Autoscaler contributed to failure
4. Review PodDisruptionBudgets — were they respected?
5. Test failover procedure in staging
6. Update this runbook with new findings
