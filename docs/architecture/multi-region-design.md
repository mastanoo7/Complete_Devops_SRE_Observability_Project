# Multi-Region Design — NexaCommerce

## Overview
NexaCommerce operates in **active-active** mode across 6+ regions spanning 3 clouds, providing global coverage with < 100ms latency for 95% of users.

---

## Region Map

```
Americas:
  AWS us-east-1      (Primary — 25% global traffic)
  AWS us-west-2      (DR — failover target)
  GCP us-central1    (15% global traffic)

EMEA:
  Azure westeurope   (Primary EMEA — 25% global traffic)
  Azure eastus2      (DR for Azure)

APAC:
  GCP asia-east1     (10% APAC traffic)
  AWS ap-southeast-1 (Planned Q3 2024)
```

---

## Traffic Routing Strategy

### CloudFlare Global Load Balancer

```yaml
Routing Policy: Dynamic Latency
  - Routes each user to lowest-latency healthy origin
  - Health check interval: 30 seconds
  - Failover threshold: 2 consecutive failures

Traffic Distribution (normal):
  AWS us-east-1:    40% (Americas primary)
  Azure westeurope: 35% (EMEA primary)
  GCP us-central1:  25% (APAC + overflow)

Session Affinity:
  Type: Cookie-based
  TTL: 30 minutes
  Reason: Cart and session consistency
```

### Geo-Routing Rules

| User Region | Primary | Secondary | Tertiary |
|-------------|---------|-----------|---------|
| North America | AWS us-east-1 | GCP us-central1 | Azure eastus2 |
| Europe | Azure westeurope | AWS us-east-1 | GCP us-central1 |
| Asia Pacific | GCP asia-east1 | AWS ap-southeast-1 | Azure eastus2 |
| South America | AWS us-east-1 | GCP us-central1 | Azure eastus2 |

---

## Data Consistency Strategy

### Database Replication

```
Write Operations:
  Primary: AWS Aurora (us-east-1) — synchronous
  Replica: AWS Aurora (us-west-2) — async, RPO < 1s
  Replica: Azure CosmosDB — async via CDC, RPO < 5s
  Replica: GCP Cloud SQL — async via CDC, RPO < 5s

Read Operations:
  Route to nearest read replica
  Cache-aside with Redis (TTL: 5min for products)
  Stale reads acceptable for catalog (not orders/payments)
```

### Eventual Consistency Boundaries

| Data Type | Consistency | Replication |
|-----------|------------|-------------|
| User sessions | Strong | Redis cluster |
| Shopping cart | Strong | Redis cluster |
| Orders | Strong | Aurora primary |
| Payments | Strong | Aurora primary |
| Product catalog | Eventual | Aurora → replicas |
| Inventory | Strong | Aurora primary |
| Recommendations | Eventual | MongoDB → replicas |

---

## Cross-Region Communication

### Kafka MirrorMaker 2 (Event Replication)

```
AWS MSK (us-east-1) → Azure Event Hubs (westeurope)
AWS MSK (us-east-1) → GCP Pub/Sub (us-central1)

Topics replicated:
  - order.created
  - payment.processed
  - inventory.updated
  - user.registered

Replication lag target: < 1 second
```

---

## Latency Targets by Region

| User Location | Target P99 | Current P99 |
|---------------|-----------|-------------|
| US East | < 100ms | ~45ms |
| US West | < 150ms | ~80ms |
| Europe | < 100ms | ~55ms |
| Asia Pacific | < 200ms | ~120ms |
| South America | < 250ms | ~180ms |

---

## Multi-Region Deployment Process

### Rolling Deployment Across Regions

```
1. Deploy to DEV (AWS us-east-1)
2. Run smoke tests
3. Deploy to STAGING (AWS us-east-1)
4. Run E2E + performance tests
5. Deploy to PROD AWS us-east-1 (canary 5%)
6. Monitor 10 minutes → promote to 100%
7. Deploy to PROD Azure westeurope
8. Monitor 10 minutes
9. Deploy to PROD GCP us-central1
10. Monitor 10 minutes
11. Deploy to remaining regions
```

---

## Related Documents
- [Disaster Recovery](disaster-recovery.md)
- [High-Level Architecture](../diagrams/high-level-architecture.mmd)
- [Disaster Recovery Diagram](../diagrams/disaster-recovery.mmd)
- [AWS Architecture](aws-architecture.md)
- [Azure Architecture](azure-architecture.md)
- [GCP Architecture](gcp-architecture.md)
