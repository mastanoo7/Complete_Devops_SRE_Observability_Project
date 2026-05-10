# Observability Architecture — NexaCommerce

## Overview
NexaCommerce implements the **three pillars of observability**: metrics, logs, and traces — unified through OpenTelemetry and visualized in Grafana.

---

## Observability Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Metrics | Prometheus + Thanos | Time-series metrics, long-term storage |
| Logs | Loki + Promtail | Log aggregation, structured querying |
| Traces | Jaeger + Tempo | Distributed tracing, latency analysis |
| Collection | OpenTelemetry Collector | Unified telemetry pipeline |
| Visualization | Grafana | Dashboards, alerts, SLO tracking |
| Alerting | AlertManager | Alert routing, dedup, silencing |
| APM | Application Insights (Azure) | Azure-native APM |
| Cloud Metrics | CloudWatch / Azure Monitor / Cloud Monitoring | Cloud-native metrics |

---

## Metrics Pipeline

```
Services (Prometheus /metrics endpoint)
    ↓ scrape (15s interval)
Prometheus HA Pair
    ↓ remote_write
Thanos Sidecar → Thanos Store → S3 (long-term)
    ↓ query
Grafana (unified dashboards)
    ↓ alert
AlertManager → PagerDuty / Slack
```

### Key Metric Categories

| Category | Examples |
|----------|---------|
| RED Metrics | Request rate, error rate, duration |
| USE Metrics | CPU utilization, saturation, errors |
| SLO Metrics | Availability ratio, error budget |
| Business Metrics | Orders/min, revenue/min, conversion rate |
| Infrastructure | Node CPU/memory, pod restarts, PVC usage |

---

## Logging Pipeline

```
Pod stdout/stderr
    ↓ Promtail DaemonSet
Loki (distributed mode, S3 backend)
    ↓ query
Grafana (LogQL)

Pod logs → FluentBit DaemonSet → Elasticsearch → Kibana
(parallel pipeline for full-text search)
```

### Log Standards
All services emit **structured JSON logs**:
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "level": "info",
  "service": "product-service",
  "traceId": "abc123",
  "spanId": "def456",
  "message": "Product fetched from cache",
  "productId": "prod-001",
  "duration_ms": 2
}
```

### Log Retention
| Tier | Duration | Storage |
|------|----------|---------|
| Hot (recent) | 7 days | Loki/ES in-cluster |
| Warm | 30 days | S3 Standard |
| Cold | 1 year | S3 Glacier |
| Compliance | 7 years | S3 Glacier Deep Archive |

---

## Tracing Pipeline

```
Services (OpenTelemetry SDK)
    ↓ OTLP gRPC (port 4317)
OTel Collector (tail sampling)
    ↓
Jaeger Collector → Elasticsearch (traces)
Tempo → S3 (traces)
    ↓ query
Grafana (trace visualization + service map)
```

### Sampling Strategy
| Scenario | Sample Rate |
|----------|------------|
| Normal traffic | 10% |
| Error requests | 100% |
| Slow requests (>1s) | 100% |
| Payment service | 100% |
| Health checks | 0% |

---

## Dashboards

| Dashboard | Purpose | Audience |
|-----------|---------|---------|
| SLO Overview | Platform availability + error budget | SRE, Management |
| Service Health | Per-service RED metrics | Engineers |
| Infrastructure | Node/pod resource usage | Platform team |
| Business KPIs | Orders, revenue, conversion | Product, Business |
| Security | Falco alerts, auth failures | Security team |
| Kubernetes | Cluster health, deployments | Platform team |
| Istio | Service mesh traffic | Platform team |

---

## Alerting Strategy

### Alert Severity Levels
| Severity | Response | Channel |
|----------|---------|---------|
| Critical | Page on-call immediately | PagerDuty + Slack #alerts-critical |
| Warning | Notify team | Slack #alerts-warning |
| Info | Log only | Slack #alerts-info |

### Multi-Window Burn Rate Alerts
```promql
# Fast burn (14.4x over 1h) → Critical
# Slow burn (6x over 6h) → Warning
# These catch both sudden spikes and gradual degradation
```

---

## Related Documents
- [Observability Flow Diagram](../diagrams/observability-flow.mmd)
- [Prometheus Config](../../monitoring/prometheus/prometheus.yml)
- [Alert Rules](../../monitoring/prometheus/rules/)
- [Grafana Dashboards](../../monitoring/grafana/dashboards/)
- [Monitoring Setup Guide](../setup/monitoring-setup.md)
