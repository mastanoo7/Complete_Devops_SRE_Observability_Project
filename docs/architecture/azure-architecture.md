# Azure Architecture — NexaCommerce

## Overview
Azure serves as the **secondary cloud** (35% of production traffic), providing geographic redundancy for EMEA traffic and disaster recovery for AWS.

---

## Regions & Availability Zones

| Region | Role | AZs Used |
|--------|------|----------|
| `westeurope` | Primary Azure | 1, 2, 3 |
| `eastus2` | DR / Secondary | 1, 2 |

---

## Network Architecture

### VNet Design (westeurope)

```
VNet: 10.10.0.0/16
├── AKS System Subnet:  10.10.1.0/24
├── AKS App Subnet:     10.10.2.0/22
├── Data Subnet:        10.10.10.0/24
└── App Gateway Subnet: 10.10.20.0/24
```

---

## Compute — Azure AKS

### Cluster Configuration

```yaml
Cluster Name:     nexacommerce-prod
K8s Version:      1.29
Network Plugin:   Azure CNI
Network Policy:   Azure
RBAC:             Azure AD + Workload Identity
Monitoring:       Container Insights + Log Analytics
Auto-upgrade:     Patch channel
```

### Node Pools

| Pool | VM Size | Min | Max | Purpose |
|------|---------|-----|-----|---------|
| `system` | Standard_D4s_v3 | 3 | 6 | System pods |
| `appgeneral` | Standard_D8s_v3 | 3 | 30 | App workloads |
| `appspot` | Standard_D8s_v3 (Spot) | 0 | 20 | Batch/non-critical |

---

## Database — CosmosDB + PostgreSQL

### CosmosDB (Global Document DB)
```
API:              Core (SQL)
Consistency:      Session (default), Strong (payments)
Multi-region:     westeurope (write) + eastus2 (write)
Automatic failover: Enabled
Backup:           Continuous (30 days)
```

### Azure Database for PostgreSQL Flexible Server
```
Version:          PostgreSQL 15
SKU:              GP_Standard_D8s_v3
HA:               Zone Redundant (zones 1 + 2)
Backup:           35 days, geo-redundant
```

---

## Caching — Azure Cache for Redis

```
SKU:              Premium P3
Geo-replication:  westeurope → eastus2
TLS:              Enabled (1.2+)
Persistence:      RDB snapshots
```

---

## Security Services

| Service | Purpose |
|---------|---------|
| Azure Key Vault (Premium) | Secrets, certificates, HSM keys |
| Microsoft Defender for Containers | Runtime threat detection |
| Azure Policy | CIS benchmark compliance |
| Azure AD Workload Identity | Pod-level managed identity |
| Azure DDoS Protection Standard | L3/L4/L7 DDoS mitigation |
| Azure Front Door WAF | OWASP Top 10, rate limiting |

---

## Cost Optimization

| Strategy | Savings |
|----------|---------|
| Spot instances (batch) | ~70% |
| Reserved instances (1yr) | ~40% |
| Azure Hybrid Benefit | ~40% on Windows VMs |
| Dev/Test pricing | ~55% on non-prod |

---

## Related

- [Azure Infrastructure Diagram](../diagrams/azure-infrastructure.mmd)
- [Terraform AKS Module](../../terraform/modules/aks/)
- [Azure Setup Guide](../setup/azure-setup.md)
