# Capacity Planning — NexaCommerce

## Overview
This document defines capacity planning methodology, current baselines, growth projections, and scaling thresholds for the NexaCommerce platform.

---

## Current Baseline (Production)

### Traffic Metrics
| Metric | Current | Peak | Growth Rate |
|--------|---------|------|-------------|
| Requests/second | 5,000 | 25,000 | +15%/month |
| Concurrent users | 50,000 | 250,000 | +15%/month |
| Orders/day | 100,000 | 500,000 | +20%/month |
| Data ingested/day | 500 GB | 2 TB | +10%/month |

### Compute Resources (Production)
| Cluster | Nodes | vCPUs | Memory | Utilization |
|---------|-------|-------|--------|-------------|
| EKS (AWS) | 18 | 144 | 576 GB | 65% avg |
| AKS (Azure) | 15 | 120 | 480 GB | 60% avg |
| GKE (GCP) | 12 | 96 | 384 GB | 55% avg |

---

## Scaling Thresholds

### Horizontal Pod Autoscaler Triggers
| Service | Scale Up | Scale Down | Min | Max |
|---------|----------|------------|-----|-----|
| frontend | CPU > 70% | CPU < 30% | 3 | 20 |
| auth-service | CPU > 70% | CPU < 30% | 3 | 15 |
| product-service | CPU > 70% | CPU < 30% | 3 | 20 |
| cart-service | CPU > 70% | CPU < 30% | 3 | 15 |
| order-service | CPU > 70% | CPU < 30% | 3 | 15 |
| payment-service | CPU > 60% | CPU < 25% | 3 | 10 |
| search-service | CPU > 70% | CPU < 30% | 3 | 20 |

### Cluster Autoscaler Triggers
| Node Group | Scale Up | Scale Down | Min | Max |
|-----------|----------|------------|-----|-----|
| system | Pending pods | Underutilized 10min | 3 | 6 |
| app-general | Pending pods | Underutilized 10min | 3 | 30 |
| app-memory | Pending pods | Underutilized 10min | 3 | 15 |
| app-spot | Pending pods | Underutilized 10min | 0 | 20 |

---

## Growth Projections

### 6-Month Forecast
| Month | RPS | Nodes (AWS) | Storage | Cost/Month |
|-------|-----|-------------|---------|-----------|
| Current | 5,000 | 18 | 10 TB | $12,000 |
| +1 month | 5,750 | 21 | 11 TB | $13,500 |
| +3 months | 7,600 | 27 | 13 TB | $17,000 |
| +6 months | 11,500 | 36 | 17 TB | $24,000 |

### Scaling Milestones

**10,000 RPS** (estimated: Month 4):
- Add 3rd Aurora read replica
- Increase Redis cluster to 6 shards
- Add Elasticsearch data nodes (3 → 5)
- Review Kafka partition count

**50,000 RPS** (estimated: Month 12):
- Evaluate database sharding strategy
- Add dedicated search cluster
- Consider CDN-side compute (Cloudflare Workers)
- Review multi-region database writes

**100,000 RPS** (estimated: Month 18):
- Full database sharding
- Dedicated payment processing cluster
- Global Kafka deployment
- Consider CQRS pattern for read-heavy services

---

## Database Capacity

### Aurora PostgreSQL
```
Current:
  Storage: 2 TB (auto-scaling to 128 TB)
  Connections: 400 avg / 800 peak (limit: 1000)
  IOPS: 3,000 avg / 8,000 peak

Action at 70% connections (700):
  - Add read replica
  - Implement PgBouncer connection pooling

Action at 80% storage (1.6 TB):
  - Review data archival strategy
  - Implement table partitioning for orders
```

### ElastiCache Redis
```
Current:
  Memory: 60% utilized
  Connections: 500 avg / 1,200 peak
  Evictions: 0 (target: 0)

Action at 80% memory:
  - Add shard to cluster
  - Review TTL strategy
  - Implement cache warming

Action at 1,000 connections:
  - Add Redis proxy (Twemproxy)
  - Review connection pooling in services
```

---

## Cost Optimization Strategies

### Current Optimizations
| Strategy | Savings | Status |
|----------|---------|--------|
| Spot instances (batch) | ~$800/month | Active |
| Reserved instances (1yr) | ~$2,400/month | Active |
| S3 Intelligent-Tiering | ~$300/month | Active |
| Graviton3 nodes | ~$600/month | Active |
| Aurora Serverless (dev) | ~$400/month | Active |

### Planned Optimizations
| Strategy | Estimated Savings | Timeline |
|----------|------------------|---------|
| Savings Plans (3yr) | ~$3,000/month | Q2 2024 |
| Spot for stateless services | ~$1,500/month | Q2 2024 |
| Data tiering (S3 Glacier) | ~$500/month | Q3 2024 |
| Right-sizing (VPA recommendations) | ~$800/month | Q2 2024 |

---

## Capacity Review Schedule

| Review | Frequency | Participants | Output |
|--------|-----------|-------------|--------|
| Weekly metrics review | Weekly | SRE team | Trend report |
| Capacity planning | Monthly | SRE + Eng Managers | Scaling plan |
| Budget review | Monthly | SRE + Finance | Cost forecast |
| Annual capacity plan | Annually | All engineering | 12-month roadmap |

---

## Monitoring Queries

```promql
# Current cluster CPU utilization
avg(100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))

# Pod density per node
count(kube_pod_info{namespace="nexacommerce-prod"}) by (node)

# Memory pressure
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# HPA current vs desired replicas
kube_horizontalpodautoscaler_status_current_replicas{namespace="nexacommerce-prod"}
/ kube_horizontalpodautoscaler_spec_max_replicas{namespace="nexacommerce-prod"}
```

---

## Related Documents
- [SLIs/SLOs/SLAs](../sre/slis-slos-slas.md)
- [AWS Architecture](../architecture/aws-architecture.md)
- [Kubernetes Architecture](../architecture/kubernetes-architecture.md)
- [Grafana Capacity Dashboard](https://grafana.nexacommerce.com/d/capacity)
