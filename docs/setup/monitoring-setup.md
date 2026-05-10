# Monitoring Setup Guide — NexaCommerce

## Overview
This guide covers deploying the full observability stack: Prometheus, Grafana, Loki, Tempo, Jaeger, and OpenTelemetry Collector.

---

## Prerequisites

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

---

## Step 1: Deploy Prometheus Stack

```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Install kube-prometheus-stack (Prometheus + Grafana + AlertManager)
helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=fast-ssd \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=100Gi \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --set grafana.adminPassword=YourGrafanaPassword \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=10Gi

# Apply custom Prometheus config
kubectl create configmap prometheus-config \
  --from-file=monitoring/prometheus/prometheus.yml \
  -n monitoring

# Apply alert rules
kubectl apply -f monitoring/prometheus/rules/ -n monitoring

# Apply AlertManager config
kubectl create secret generic alertmanager-config \
  --from-file=alertmanager.yaml=monitoring/prometheus/alertmanager.yml \
  -n monitoring
```

---

## Step 2: Deploy Loki (Log Aggregation)

```bash
# Install Loki distributed
helm install loki grafana/loki \
  --namespace monitoring \
  --set loki.storage.type=s3 \
  --set loki.storage.s3.region=us-east-1 \
  --set loki.storage.s3.bucketnames=nexacommerce-loki-prod \
  --set loki.auth_enabled=false

# Install Promtail (log collector)
helm install promtail grafana/promtail \
  --namespace monitoring \
  --set config.lokiAddress=http://loki:3100/loki/api/v1/push

# Apply custom Promtail config
kubectl create configmap promtail-config \
  --from-file=logging/promtail/promtail-prod.yaml \
  -n monitoring
```

---

## Step 3: Deploy Jaeger (Distributed Tracing)

```bash
# Install Jaeger Operator
kubectl create namespace observability
kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.53.0/jaeger-operator.yaml \
  -n observability

# Deploy Jaeger instance
cat <<EOF | kubectl apply -f -
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: nexacommerce-jaeger
  namespace: monitoring
spec:
  strategy: production
  storage:
    type: elasticsearch
    elasticsearch:
      nodeCount: 3
      resources:
        requests:
          cpu: 1
          memory: 2Gi
EOF
```

---

## Step 4: Deploy OpenTelemetry Collector

```bash
# Install OTel Operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

# Deploy OTel Collector
kubectl create configmap otel-collector-config \
  --from-file=monitoring/opentelemetry/otel-collector.yaml \
  -n monitoring

cat <<EOF | kubectl apply -f -
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: nexacommerce-otel
  namespace: monitoring
spec:
  mode: DaemonSet
  config: |
    $(cat monitoring/opentelemetry/otel-collector.yaml)
EOF
```

---

## Step 5: Configure Grafana Dashboards

```bash
# Apply datasource provisioning
kubectl create configmap grafana-datasources \
  --from-file=monitoring/grafana/provisioning/datasources/datasources.yaml \
  -n monitoring

# Import SLO dashboard
kubectl create configmap grafana-dashboards \
  --from-file=monitoring/grafana/dashboards/ \
  -n monitoring

# Access Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana 3001:80 -n monitoring &
echo "Grafana: http://localhost:3001 (admin/YourGrafanaPassword)"
```

---

## Step 6: Verify Observability Stack

```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# Test Prometheus
kubectl port-forward svc/prometheus-operated 9090:9090 -n monitoring &
curl http://localhost:9090/-/healthy

# Test Loki
kubectl port-forward svc/loki 3100:3100 -n monitoring &
curl http://localhost:3100/ready

# Test Jaeger
kubectl port-forward svc/nexacommerce-jaeger-query 16686:16686 -n monitoring &
echo "Jaeger UI: http://localhost:16686"

# Verify metrics flowing
curl -s http://localhost:9090/api/v1/query \
  --data-urlencode 'query=up' | jq '.data.result | length'
```

---

## Grafana Dashboard URLs

| Dashboard | URL |
|-----------|-----|
| SLO Overview | https://grafana.nexacommerce.com/d/slo-overview |
| Service Health | https://grafana.nexacommerce.com/d/service-health |
| Infrastructure | https://grafana.nexacommerce.com/d/infrastructure |
| Kubernetes | https://grafana.nexacommerce.com/d/kubernetes |
| Istio | https://grafana.nexacommerce.com/d/istio |

---

## Related
- [Observability Architecture](../architecture/observability-architecture.md)
- [Prometheus Config](../../monitoring/prometheus/prometheus.yml)
- [Alert Rules](../../monitoring/prometheus/rules/)
- [Grafana Dashboards](../../monitoring/grafana/dashboards/)
