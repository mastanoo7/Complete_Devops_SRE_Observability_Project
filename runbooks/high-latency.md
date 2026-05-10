# Runbook: High Latency

**Severity**: P2–P3 | **Team**: Platform SRE | **Last Updated**: 2024-01

---

## Alert
```
Alert: ProductServiceLatencySLOBreach
Condition: histogram_quantile(0.99, ...) > 0.5 for 5m
Alert: PaymentServiceLatencySLOBreach
Condition: histogram_quantile(0.99, ...) > 3.0 for 2m
```

---

## Symptoms
- P99 latency exceeds SLO threshold
- Users reporting slow page loads
- Grafana SLO dashboard showing red
- Increased error budget burn rate

---

## Quick Triage

```bash
# Check current P99 latency per service
kubectl exec -n monitoring deploy/prometheus -- \
  promtool query instant \
  'histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{namespace="nexacommerce-prod"}[5m])) by (le, service))'

# Check request rate (traffic spike?)
kubectl exec -n monitoring deploy/prometheus -- \
  promtool query instant \
  'sum(rate(http_requests_total{namespace="nexacommerce-prod"}[5m])) by (service)'

# Check pod CPU/memory
kubectl top pods -n nexacommerce-prod --sort-by=cpu | head -20
kubectl top pods -n nexacommerce-prod --sort-by=memory | head -20
```

---

## Diagnosis Steps

### Step 1: Identify Affected Service

```bash
# Find which service has highest latency
kubectl exec -n monitoring deploy/prometheus -- \
  promtool query instant \
  'topk(5, histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{namespace="nexacommerce-prod"}[5m])) by (le, service)))'
```

### Step 2: Check for Traffic Spike

```bash
# Compare current RPS vs baseline (1h ago)
# In Grafana: d/service-health → Request Rate panel

# Check Kong rate limiting
kubectl logs -n kong deploy/kong --tail=100 | grep "rate limit"

# Check HPA status
kubectl get hpa -n nexacommerce-prod
kubectl describe hpa <service-name> -n nexacommerce-prod
```

### Step 3: Check Database Performance

```bash
# Check Aurora slow queries (via CloudWatch)
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ReadLatency \
  --dimensions Name=DBClusterIdentifier,Value=nexacommerce-prod-aurora \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average

# Check connection pool exhaustion
kubectl exec -n nexacommerce-prod deploy/product-service -- \
  curl -s localhost:8082/actuator/metrics/hikaricp.connections.active | jq .

# Check Redis latency
kubectl exec -n nexacommerce-prod deploy/cart-service -- \
  redis-cli -h redis.nexacommerce.internal ping
```

### Step 4: Check Istio Circuit Breaker

```bash
# Check if circuit breaker is open
kubectl exec -n istio-system deploy/istiod -- \
  pilot-discovery request GET /debug/endpointz | \
  jq '.[] | select(.service | contains("product-service"))'

# Check Envoy stats for upstream errors
kubectl exec -n nexacommerce-prod <pod-name> -c istio-proxy -- \
  pilot-agent request GET stats | grep "upstream_rq_timeout"
```

### Step 5: Check External Dependencies

```bash
# Check Elasticsearch latency (search service)
kubectl exec -n nexacommerce-prod deploy/search-service -- \
  curl -s "http://elasticsearch:9200/_cluster/health" | jq .status

# Check Kafka consumer lag
kubectl exec -n nexacommerce-prod deploy/order-service -- \
  kafka-consumer-groups.sh \
  --bootstrap-server kafka:9092 \
  --describe \
  --group order-service-prod
```

---

## Remediation

### Option 1: Scale Up Affected Service

```bash
# Immediate scale-up
kubectl scale deployment/<service-name> \
  --replicas=10 \
  -n nexacommerce-prod

# Update HPA max replicas temporarily
kubectl patch hpa <service-name> -n nexacommerce-prod \
  --type=json \
  -p='[{"op":"replace","path":"/spec/maxReplicas","value":30}]'

# Monitor scale-up
kubectl rollout status deployment/<service-name> -n nexacommerce-prod
```

### Option 2: Enable Circuit Breaker

```bash
# Apply aggressive circuit breaker via Istio DestinationRule
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: <service-name>-emergency-cb
  namespace: nexacommerce-prod
spec:
  host: <service-name>
  trafficPolicy:
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
EOF
```

### Option 3: Enable Caching (Product Service)

```bash
# Increase Redis TTL for product cache
kubectl exec -n nexacommerce-prod deploy/product-service -- \
  curl -X POST localhost:8082/actuator/env \
  -H "Content-Type: application/json" \
  -d '{"name":"CACHE_TTL_PRODUCTS","value":"600"}'
```

### Option 4: Traffic Shedding (Last Resort)

```bash
# Reduce Kong rate limits to protect backend
kubectl patch kongplugin rate-limiting -n kong \
  --type=json \
  -p='[{"op":"replace","path":"/config/minute","value":500}]'

# Enable maintenance mode for non-critical endpoints
kubectl apply -f scripts/maintenance/maintenance-mode.yaml
```

### Option 5: Database Read Replica Routing

```bash
# Force read traffic to read replicas
kubectl set env deployment/product-service \
  SPRING_DATASOURCE_URL="jdbc:postgresql://aurora-reader.nexacommerce.internal:5432/product_db" \
  -n nexacommerce-prod
```

---

## Verification

```bash
# Monitor P99 latency recovery
watch -n 10 'kubectl exec -n monitoring deploy/prometheus -- \
  promtool query instant \
  "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{service=\"product-service\"}[5m])) by (le))"'

# Check SLO compliance
# Grafana: https://grafana.nexacommerce.com/d/slo-overview
```

---

## Post-Incident
1. Identify root cause (traffic spike, slow query, memory pressure)
2. Tune HPA thresholds if scaling was too slow
3. Add database query optimization if slow queries found
4. Review and update circuit breaker thresholds
5. Consider adding read replicas if DB was bottleneck
