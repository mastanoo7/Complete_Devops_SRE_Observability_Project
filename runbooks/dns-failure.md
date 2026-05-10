# Runbook: DNS Failure

**Severity**: P1 | **Team**: Platform SRE | **Last Updated**: 2024-01

---

## Alert
```
Alert: DNSResolutionFailure
Condition: probe_dns_lookup_time_seconds > 5 for 2m
Or: blackbox probe_success{job="dns-check"} == 0
```

---

## Symptoms
- Services unable to reach each other by hostname
- External DNS resolution failing
- CoreDNS pods crashing or unresponsive
- Increased latency on all service-to-service calls

---

## Quick Triage

```bash
# Test external DNS from a pod
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- \
  nslookup api.nexacommerce.com

# Test internal DNS (service discovery)
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never \
  -n nexacommerce-prod -- \
  nslookup auth-service.nexacommerce-prod.svc.cluster.local

# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
```

---

## Diagnosis

### Step 1: Check CoreDNS Health

```bash
# Check CoreDNS pod status
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide

# Check CoreDNS logs for errors
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100 | \
  grep -E "ERROR|WARN|panic"

# Check CoreDNS configmap
kubectl get configmap coredns -n kube-system -o yaml

# Check CoreDNS metrics
kubectl port-forward -n kube-system svc/kube-dns 9153:9153 &
curl -s http://localhost:9153/metrics | grep coredns_dns_request_duration
```

### Step 2: Check DNS Resolution Chain

```bash
# Test from within a pod
kubectl exec -n nexacommerce-prod deploy/auth-service -- \
  nslookup product-service.nexacommerce-prod.svc.cluster.local

# Check resolv.conf in pod
kubectl exec -n nexacommerce-prod deploy/auth-service -- \
  cat /etc/resolv.conf

# Test with dig
kubectl run dig-test --image=tutum/dnsutils --rm -it --restart=Never -- \
  dig @10.96.0.10 product-service.nexacommerce-prod.svc.cluster.local
```

### Step 3: Check External DNS

```bash
# Check Route53 health (AWS)
aws route53 get-health-check-status \
  --health-check-id <health-check-id>

# Check CloudFlare DNS
curl -s "https://cloudflare-dns.com/dns-query?name=api.nexacommerce.com&type=A" \
  -H "Accept: application/dns-json" | jq .

# Check DNS propagation
dig @8.8.8.8 api.nexacommerce.com
dig @1.1.1.1 api.nexacommerce.com
```

### Step 4: Check Node-Level DNS

```bash
# SSH to a node and test DNS
ssh ec2-user@<node-ip>
nslookup google.com
cat /etc/resolv.conf
systemctl status systemd-resolved
```

---

## Remediation

### Option 1: Restart CoreDNS

```bash
# Rolling restart of CoreDNS
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout status deployment/coredns -n kube-system

# Verify CoreDNS is healthy
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

### Option 2: Scale Up CoreDNS

```bash
# If CoreDNS is overloaded, scale up
kubectl scale deployment/coredns --replicas=5 -n kube-system

# Check CoreDNS resource usage
kubectl top pods -n kube-system -l k8s-app=kube-dns
```

### Option 3: Fix CoreDNS ConfigMap

```bash
# Edit CoreDNS config if misconfigured
kubectl edit configmap coredns -n kube-system

# Standard working config:
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
EOF
```

### Option 4: Fix External DNS (Route53)

```bash
# Check if Route53 records are correct
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Name=='api.nexacommerce.com.']"

# Update A record if needed
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch file://scripts/dns/update-api-record.json
```

---

## Verification

```bash
# Verify internal DNS works
kubectl run dns-verify --image=busybox:1.28 --rm -it --restart=Never \
  -n nexacommerce-prod -- \
  nslookup auth-service.nexacommerce-prod.svc.cluster.local

# Verify external DNS works
kubectl run dns-verify --image=busybox:1.28 --rm -it --restart=Never -- \
  nslookup api.nexacommerce.com

# Check service-to-service calls working
kubectl exec -n nexacommerce-prod deploy/order-service -- \
  curl -s http://payment-service/health/ready | jq .status
```

---

## Post-Incident
1. Review CoreDNS resource limits — increase if consistently high CPU
2. Add DNS query rate monitoring
3. Consider NodeLocal DNSCache for high-traffic clusters
4. Review TTL settings for external DNS records
