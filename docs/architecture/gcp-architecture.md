# GCP Architecture — NexaCommerce

## Overview
GCP serves as the **tertiary cloud** (25% of production traffic), handling APAC traffic and ML workloads (Vertex AI recommendations, demand forecasting).

---

## Regions

| Region | Role | Zones Used |
|--------|------|-----------|
| `us-central1` | Primary GCP | a, b, c, f |
| `us-east1` | Read replica | b, c, d |
| `asia-east1` | APAC traffic | a, b, c |

---

## Network Architecture

### VPC Design (us-central1)

```
VPC: nexacommerce-prod-vpc (global)
├── GKE Subnet:      10.20.0.0/20  (us-central1)
│   ├── Pods:        10.21.0.0/16  (secondary range)
│   └── Services:    10.22.0.0/20  (secondary range)
├── Data Subnet:     10.20.16.0/24 (us-central1)
└── Master CIDR:     172.16.0.0/28 (GKE control plane)
```

---

## Compute — Google GKE

### Cluster Configuration

```yaml
Cluster Name:       nexacommerce-prod
K8s Version:        1.29
Type:               Standard (not Autopilot)
Network:            VPC-native (alias IPs)
Workload Identity:  Enabled
Binary Authorization: Enforced
Managed Prometheus: Enabled
Release Channel:    Regular
```

### Node Pools

| Pool | Machine Type | Min | Max | Purpose |
|------|-------------|-----|-----|---------|
| `system` | e2-standard-4 | 1 | 3 | System pods |
| `app-general` | n2-standard-8 | 3 | 30 | App workloads |
| `app-spot` | n2-standard-8 (Spot) | 0 | 20 | Batch/non-critical |

---

## Database — Cloud SQL + Cloud Spanner

### Cloud SQL PostgreSQL 15
```
Tier:             db-custom-8-32768
Availability:     Regional (HA)
Disk:             100 GB SSD, auto-resize
Backup:           Daily, PITR enabled
Read Replica:     us-east1 (async)
SSL:              Required
```

### Memorystore Redis 7.0
```
Tier:             Standard HA
Memory:           16 GB
Auth:             Enabled
TLS:              Server authentication
Maintenance:      Sunday 02:00 UTC
```

---

## ML Platform — Vertex AI

| Service | Use Case |
|---------|---------|
| Vertex AI Feature Store | User/product features for recommendations |
| Vertex AI Predictions | Real-time recommendation serving |
| Vertex AI Pipelines | Model training pipelines |
| BigQuery ML | Demand forecasting |
| Vertex AI Search | Semantic product search |

---

## Security Services

| Service | Purpose |
|---------|---------|
| Secret Manager | Secrets with automatic rotation |
| Cloud KMS | Encryption key management |
| Security Command Center | Threat detection + compliance |
| Binary Authorization | Only signed images deployed |
| VPC Service Controls | Data exfiltration prevention |
| Cloud Armor | WAF + DDoS protection |

---

## Cost Optimization

| Strategy | Savings |
|----------|---------|
| Spot VMs | ~70% on batch |
| Committed Use (1yr) | ~37% on compute |
| Sustained Use Discounts | ~20-30% automatic |
| Preemptible for ML training | ~80% on training jobs |

---

## Related

- [GCP Infrastructure Diagram](../diagrams/gcp-infrastructure.mmd)
- [Terraform GKE Module](../../terraform/modules/gke/)
- [GCP Setup Guide](../setup/gcp-setup.md)
