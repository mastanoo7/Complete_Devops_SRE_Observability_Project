# Runbook: Ingress Failure

**Severity**: P1–P2 | **Team**: Platform SRE | **Last Updated**: 2024-01

---

## Alert
```
Alert: IngressFailure
Condition: probe_success{job="blackbox-http"} == 0 for 2m
Or: nginx_ingress_controller_requests{status=~"5.."} / nginx_ingress_controller_requests > 0.1
```

---

## Symptoms
- Users getting 502/503/504 errors
- CloudFlare health checks failing
- ALB/Application Gateway returning errors
- Kong API Gateway not routing requests

---

## Quick Triage

```bash
# Test from outside
curl -v https://api.nexacommerce.com/health
curl -v https://nexacommerce.com

# Check Kong pods
kubectl get pods -n kong
kubectl logs -n kong deploy/kong --tail=50 | grep -E "ERROR|WARN"

# Check Istio ingress gateway
kubectl get pods -n istio-system -l istio=ingressgateway
kubectl logs -n istio-system deploy/istio-ingressgateway --tail=50

# Check ALB target health (AWS)
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --query 'TargetGroups[?contains(TargetGroupName,`nexacommerce`)].TargetGroupArn' \
    --output text)
```

---

## Diagnosis

### Step 1: Identify Failure Layer

```bash
# Layer 1: DNS resolution
nslookup api.nexacommerce.com
dig api.nexacommerce.com

# Layer 2: CloudFlare → ALB
curl -v --resolve api.nexacommerce.com:443:<ALB-IP> https://api.nexacommerce.com/health

# Layer 3: ALB → Kong
kubectl port-forward svc/kong-proxy 8080:80 -n kong &
curl -v http://localhost:8080/health

# Layer 4: Kong → Services
kubectl exec -n kong deploy/kong -- \
  curl -s http://auth-service.nexacommerce-prod/health/ready
```

### Step 2: Check Kong Configuration

```bash
# Check Kong routes
kubectl exec -n kong deploy/kong -- \
  curl -s http://localhost:8001/routes | jq '.data[].name'

# Check Kong services
kubectl exec -n kong deploy/kong -- \
  curl -s http://localhost:8001/services | jq '.data[] | {name,host,port}'

# Check Kong plugins
kubectl exec -n kong deploy/kong -- \
  curl -s http://localhost:8001/plugins | jq '.data[].name'

# Check Kong upstream health
kubectl exec -n kong deploy/kong -- \
  curl -s http://localhost:8001/upstreams | jq '.data[].name'
```

### Step 3: Check Istio Ingress Gateway

```bash
# Check gateway configuration
kubectl get gateway -n nexacommerce-prod
kubectl describe gateway nexacommerce-gateway -n nexacommerce-prod

# Check virtual services
kubectl get virtualservice -n nexacommerce-prod
kubectl describe virtualservice frontend -n nexacommerce-prod

# Check Envoy config
kubectl exec -n istio-system deploy/istio-ingressgateway -- \
  pilot-agent request GET config_dump | jq '.configs[] | select(.["@type"] | contains("Listener"))'

# Check Envoy stats
kubectl exec -n istio-system deploy/istio-ingressgateway -- \
  pilot-agent request GET stats | grep "downstream_cx_active"
```

### Step 4: Check TLS Certificates

```bash
# Check cert-manager certificates
kubectl get certificates -n nexacommerce-prod
kubectl describe certificate nexacommerce-tls -n nexacommerce-prod

# Check certificate expiry
kubectl get secret nexacommerce-tls -n nexacommerce-prod \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -dates

# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager --tail=50
```

---

## Remediation

### Option 1: Restart Kong

```bash
kubectl rollout restart deployment/kong -n kong
kubectl rollout status deployment/kong -n kong
```

### Option 2: Restart Istio Ingress Gateway

```bash
kubectl rollout restart deployment/istio-ingressgateway -n istio-system
kubectl rollout status deployment/istio-ingressgateway -n istio-system
```

### Option 3: Renew TLS Certificate

```bash
# Force cert-manager to renew
kubectl annotate certificate nexacommerce-tls \
  cert-manager.io/issue-temporary-certificate="true" \
  -n nexacommerce-prod

# Or delete and recreate
kubectl delete certificate nexacommerce-tls -n nexacommerce-prod
kubectl apply -f kubernetes/base/certificates/nexacommerce-tls.yaml
```

### Option 4: Failover to Secondary Cloud

```bash
# If AWS ALB is down, route to Azure via CloudFlare
# Update CloudFlare load balancer pool weights
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/load_balancers/${LB_ID}" \
  -H "Authorization: Bearer ${CF_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"default_pools":["azure-westeurope-pool","gcp-us-central1-pool"]}'
```

---

## Verification

```bash
# Confirm ingress is working
curl -s https://api.nexacommerce.com/health | jq .status
curl -s https://nexacommerce.com | grep -c "NexaCommerce"

# Check error rate returning to normal
# Grafana: https://grafana.nexacommerce.com/d/slo-overview
```

---

## Post-Incident
1. Review Kong/Istio logs for root cause
2. Check if certificate expiry caused the issue
3. Add certificate expiry alerting if missing
4. Review CloudFlare failover configuration
