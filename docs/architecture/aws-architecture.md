# AWS Architecture — NexaCommerce

## Overview
AWS serves as the **primary cloud** (40% of production traffic), hosting the main EKS clusters, Aurora PostgreSQL primary, and MSK Kafka.

---

## Regions & Availability Zones

| Region | Role | AZs Used |
|--------|------|----------|
| `us-east-1` | Primary | us-east-1a, 1b, 1c |
| `us-west-2` | DR / Secondary | us-west-2a, 2b, 2c |

---

## Network Architecture

### VPC Design (us-east-1)

```
VPC: 10.0.0.0/16
├── Public Subnets (ALB, NAT Gateway)
│   ├── 10.0.1.0/24  (us-east-1a)
│   ├── 10.0.2.0/24  (us-east-1b)
│   └── 10.0.3.0/24  (us-east-1c)
├── Private Subnets (EKS nodes)
│   ├── 10.0.11.0/24 (us-east-1a)
│   ├── 10.0.12.0/24 (us-east-1b)
│   └── 10.0.13.0/24 (us-east-1c)
└── Data Subnets (RDS, ElastiCache)
    ├── 10.0.21.0/24 (us-east-1a)
    ├── 10.0.22.0/24 (us-east-1b)
    └── 10.0.23.0/24 (us-east-1c)
```

### Security Groups

| SG Name | Inbound | Outbound | Purpose |
|---------|---------|----------|---------|
| `sg-alb` | 443, 80 from 0.0.0.0/0 | 8080 to sg-eks | ALB |
| `sg-eks-nodes` | All from sg-alb, sg-eks-nodes | All | EKS worker nodes |
| `sg-rds` | 5432 from sg-eks-nodes | None | Aurora PostgreSQL |
| `sg-redis` | 6379 from sg-eks-nodes | None | ElastiCache |
| `sg-kafka` | 9092, 9094 from sg-eks-nodes | None | MSK Kafka |

---

## Compute — Amazon EKS

### Cluster Configuration

```yaml
Cluster Name:    nexacommerce-prod
K8s Version:     1.29
Endpoint:        Private + Public (restricted to VPN CIDR)
Logging:         API, Audit, Authenticator, ControllerManager, Scheduler
Add-ons:
  - vpc-cni:          v1.16.0
  - coredns:          v1.11.1
  - kube-proxy:       v1.29.0
  - aws-ebs-csi:      v1.28.0
  - aws-efs-csi:      v1.7.6
  - aws-load-balancer-controller: v2.7.0
```

### Node Groups

| Node Group | Instance | Min | Max | Use |
|-----------|---------|-----|-----|-----|
| `system` | m5.xlarge | 3 | 6 | System pods (CoreDNS, etc.) |
| `app-general` | m5.2xlarge | 6 | 30 | General microservices |
| `app-memory` | r5.2xlarge | 3 | 15 | Redis, search, ML |
| `app-compute` | c5.2xlarge | 3 | 20 | CPU-intensive services |
| `spot-batch` | m5.xlarge (spot) | 0 | 20 | Batch jobs, non-critical |

### IRSA (IAM Roles for Service Accounts)

Each service has a dedicated IAM role:

| Service | IAM Role | Permissions |
|---------|---------|-------------|
| auth-service | `nexacommerce-auth-role` | SecretsManager:GetSecretValue |
| product-service | `nexacommerce-product-role` | S3:GetObject, S3:PutObject |
| order-service | `nexacommerce-order-role` | SQS:SendMessage, SNS:Publish |
| payment-service | `nexacommerce-payment-role` | SecretsManager, KMS:Decrypt |
| notification-service | `nexacommerce-notify-role` | SES:SendEmail, SNS:Publish |

---

## Database — Amazon Aurora PostgreSQL

### Configuration

```
Engine:          Aurora PostgreSQL 15.4
Instance Class:  db.r6g.2xlarge (writer), db.r6g.xlarge (readers)
Multi-AZ:        Yes (3 AZs)
Storage:         Auto-scaling, 100GB → 128TB
Encryption:      AWS KMS (CMK)
Backup:          Automated, 35-day retention
PITR:            Enabled (RPO: 5 minutes)
Global Database: Enabled (us-west-2 replica, RPO < 1s)
```

### Database per Service

| Database | Service | Schema |
|----------|---------|--------|
| `auth_db` | auth-service | users, sessions, oauth_tokens |
| `product_db` | product-service | products, categories, images |
| `order_db` | order-service | orders, order_items, order_events |
| `payment_db` | payment-service | payments, refunds, payment_methods |
| `inventory_db` | inventory-service | inventory, reservations, warehouses |

---

## Caching — ElastiCache Redis

```
Engine:          Redis 7.x
Mode:            Cluster Mode Enabled
Shards:          3 shards × 2 replicas = 6 nodes
Node Type:       cache.r6g.xlarge
Encryption:      In-transit + at-rest
Auth:            Redis AUTH token
Backup:          Daily snapshots, 7-day retention
```

### Cache Key Strategy

| Pattern | TTL | Use Case |
|---------|-----|---------|
| `session:{userId}` | 24h | User sessions |
| `product:{id}` | 5min | Product details |
| `cart:{userId}` | 7d | Shopping cart |
| `search:{query_hash}` | 1min | Search results |
| `rate_limit:{ip}:{endpoint}` | 1min | Rate limiting |

---

## Messaging — Amazon MSK (Kafka)

```
Kafka Version:   3.5.1
Brokers:         3 (one per AZ)
Instance Type:   kafka.m5.2xlarge
Storage:         2TB per broker (gp3)
Replication:     3 (RF=3)
Retention:       7 days
Encryption:      TLS in-transit, KMS at-rest
```

### Topics

| Topic | Partitions | Consumers |
|-------|-----------|-----------|
| `order.created` | 12 | inventory-service, notification-service |
| `order.updated` | 12 | notification-service |
| `payment.processed` | 12 | order-service, notification-service |
| `inventory.updated` | 6 | product-service |
| `user.registered` | 6 | notification-service, recommendation-service |

---

## Storage — Amazon S3

| Bucket | Purpose | Lifecycle |
|--------|---------|-----------|
| `nexacommerce-assets-prod` | Product images, media | Intelligent-Tiering |
| `nexacommerce-logs-prod` | ALB, CloudFront logs | 90d → Glacier |
| `nexacommerce-backups-prod` | DB backups, snapshots | 35d → Glacier |
| `nexacommerce-tf-state` | Terraform state | Versioned, no expiry |

---

## Security Services

| Service | Configuration |
|---------|--------------|
| **AWS Shield Advanced** | Enabled on ALB, CloudFront |
| **AWS WAF** | OWASP Top 10 rules, rate limiting |
| **AWS GuardDuty** | Threat detection, all regions |
| **AWS Security Hub** | CIS benchmark, PCI-DSS standard |
| **AWS Config** | All resources tracked, compliance rules |
| **AWS CloudTrail** | All API calls, 90-day retention |
| **AWS KMS** | CMK per service, automatic rotation |
| **AWS Secrets Manager** | DB passwords, API keys, auto-rotation |

---

## Cost Optimization

| Strategy | Savings |
|----------|---------|
| Spot instances for batch | ~70% on batch workloads |
| Reserved instances (1yr) for baseline | ~40% on steady-state |
| S3 Intelligent-Tiering | ~30% on storage |
| Aurora Serverless v2 for dev/staging | ~60% vs always-on |
| Graviton3 (arm64) instances | ~20% vs x86 |

---

## Related

- [AWS Infrastructure Diagram](../diagrams/aws-infrastructure.mmd)
- [Terraform AWS Modules](../../terraform/modules/)
- [AWS Setup Guide](../setup/aws-setup.md)
