# Runbook: Node Failure

**Severity**: P2 | **Team**: Platform SRE | **Last Updated**: 2024-01

---

## Alert
```
Alert: KubernetesNodeNotReady
Condition: kube_node_status_condition{condition="Ready",status="true"} == 0
For: 5 minutes
```

---

## Symptoms
- Node shows `NotReady` status in kubectl
- Pods on the node show `Unknown` status
- Workloads may be partially degraded
- Cluster Autoscaler may be attempting to replace node

---

## Quick Triage

```bash
# List all nodes and their status
kubectl get nodes -o wide

# Find which node is NotReady
kubectl get nodes | grep -v Ready

# Check node conditions
kubectl describe node <node-name> | grep -A 10 "Conditions:"

# Check pods on the failing node
kubectl get pods --all-namespaces \
  --field-selector spec.nodeName=<node-name>
```

---

## Diagnosis

### Step 1: Check Node Events

```bash
kubectl describe node <node-name> | tail -30

# Common conditions to look for:
# - MemoryPressure: True → Node OOM
# - DiskPressure: True → Disk full
# - PIDPressure: True → Too many processes
# - NetworkUnavailable: True → CNI issue
```

### Step 2: Check Node in Cloud Console

```bash
# AWS — check EC2 instance health
aws ec2 describe-instance-status \
  --instance-ids <instance-id> \
  --query 'InstanceStatuses[0].{State:InstanceState.Name,Status:InstanceStatus.Status}'

# Azure — check VM health
az vm get-instance-view \
  --resource-group <rg-name> \
  --name <vm-name> \
  --query instanceView.statuses

# GCP — check GCE instance
gcloud compute instances describe <instance-name> \
  --zone <zone> \
  --format="value(status)"
```

### Step 3: Check System Logs

```bash
# SSH to node (if accessible via bastion)
ssh -J bastion ec2-user@<node-ip>

# Check system logs
sudo journalctl -u kubelet --since "1 hour ago" | tail -50
sudo journalctl -u containerd --since "1 hour ago" | tail -20

# Check disk usage
df -h
du -sh /var/lib/kubelet/*

# Check memory
free -h
cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable"
```

---

## Remediation

### Option 1: Cordon and Drain (Graceful)

```bash
# Prevent new pods from scheduling on node
kubectl cordon <node-name>

# Drain existing pods (respects PDBs)
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=60 \
  --timeout=300s

# Verify pods moved to other nodes
kubectl get pods -n nexacommerce-prod -o wide | grep -v <node-name>

# Terminate the node (AWS)
aws ec2 terminate-instances --instance-ids <instance-id>
# Node group will automatically replace it
```

### Option 2: Force Delete Stuck Pods

```bash
# If pods are stuck in Unknown state after node failure
kubectl get pods --all-namespaces \
  --field-selector spec.nodeName=<node-name> \
  -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name' \
  | tail -n +2 | while read ns pod; do
    kubectl delete pod $pod -n $ns --force --grace-period=0
  done
```

### Option 3: Restart Kubelet (if node is accessible)

```bash
# SSH to node
sudo systemctl restart kubelet
sudo systemctl status kubelet

# Check kubelet logs
sudo journalctl -u kubelet -f
```

### Option 4: Replace Node via ASG/VMSS

```bash
# AWS — terminate instance, ASG replaces automatically
aws autoscaling terminate-instance-in-auto-scaling-group \
  --instance-id <instance-id> \
  --should-decrement-desired-capacity false

# Azure — reimage VMSS instance
az vmss reimage \
  --resource-group <rg> \
  --name <vmss-name> \
  --instance-ids <id>
```

---

## Verification

```bash
# Confirm new node joined and is Ready
kubectl get nodes | grep Ready

# Confirm pods rescheduled
kubectl get pods -n nexacommerce-prod -o wide

# Check no pods stuck in Pending
kubectl get pods -n nexacommerce-prod | grep Pending

# Verify SLO not breached
# Grafana: https://grafana.nexacommerce.com/d/slo-overview
```

---

## Post-Incident
1. Check if node failure was due to resource exhaustion → tune limits
2. Review if PDBs prevented graceful drain
3. Check if Cluster Autoscaler replaced node promptly
4. Consider adding node health checks (AWS Systems Manager)
