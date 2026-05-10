# 🛒 NexaCommerce — Enterprise Multi-Cloud Ecommerce Platform

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![AWS](https://img.shields.io/badge/Cloud-AWS-orange)](docs/architecture/aws-architecture.md)
[![Azure](https://img.shields.io/badge/Cloud-Azure-blue)](docs/architecture/azure-architecture.md)
[![GCP](https://img.shields.io/badge/Cloud-GCP-red)](docs/architecture/gcp-architecture.md)
[![Kubernetes](https://img.shields.io/badge/Platform-Kubernetes-326CE5)](docs/architecture/kubernetes-architecture.md)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC)](terraform/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D)](argocd/)

> **Production-grade, FAANG-scale ecommerce platform** deployed across AWS, Azure, and GCP with full GitOps, observability, security, and SRE practices.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture Summary](#architecture-summary)
- [Quick Start](#quick-start)
- [Repository Structure](#repository-structure)
- [Documentation Navigation](#documentation-navigation)
- [Technology Stack](#technology-stack)
- [Environments](#environments)
- [Contributing](#contributing)

---

## Overview

NexaCommerce is a **FAANG-scale, enterprise-grade ecommerce platform** built with:

- **9 local services currently wired** (frontend, api-gateway, auth, product, cart, order, payment, inventory, notification)
- **Multi-cloud active-active** deployment across AWS, Azure, and GCP
- **3 environments**: DEV → STAGING → PRODUCTION
- **Full GitOps** with ArgoCD
- **Zero-downtime deployments** with blue/green and canary strategies
- **Complete observability** with Prometheus, Grafana, Loki, Tempo, Jaeger
- **Enterprise security** with Vault, Falco, Kyverno, OPA Gatekeeper
- **SRE practices** with SLIs/SLOs, error budgets, chaos engineering

---

## Architecture Summary

```
Internet → CloudFlare CDN → WAF → Global Load Balancer
    ↓
API Gateway (Kong) → Istio Service Mesh
    ↓
Microservices on Kubernetes (EKS + AKS + GKE)
    ↓
Databases (RDS Aurora + CosmosDB + Cloud Spanner)
    ↓
Observability (Prometheus + Grafana + Loki + Jaeger)
```

📐 **Full diagrams**: [docs/diagrams/](docs/diagrams/)

---

## Quick Start

```bash
# Clone repository
git clone https://github.com/your-org/nexacommerce.git
cd nexacommerce

# Start all services locally
make dev-up
```

📖 **Detailed setup**: [docs/setup/local-development.md](docs/setup/local-development.md)

---

## Repository Structure

```
nexacommerce/
├── frontend/                    # React/Next.js frontend
├── backend/                     # Microservices source code
│   ├── api-gateway/
│   ├── auth-service/
│   ├── product-service/
│   ├── cart-service/
│   ├── order-service/
│   ├── payment-service/
│   ├── inventory-service/
│   └── notification-service/
├── terraform/                   # IaC — modular Terraform
│   ├── modules/                 # Reusable modules
│   └── environments/            # Per-environment configs
├── kubernetes/                  # K8s manifests (Kustomize)
│   ├── base/                    # Base manifests
│   └── overlays/                # Per-environment overlays
├── helm/                        # Helm charts
├── argocd/                      # ArgoCD applications
├── monitoring/                  # Prometheus, Grafana configs
├── logging/                     # Loki, ELK configs
├── security/                    # Security policies
├── scripts/                     # Automation scripts
├── docs/                        # All documentation
├── runbooks/                    # Operational runbooks
├── chaos-engineering/           # Chaos experiments
├── .github/                     # GitHub Actions workflows
├── Jenkinsfile                  # Jenkins pipeline
└── Makefile                     # Developer shortcuts
```

---

## Documentation Navigation

### 🏗️ Architecture
| Document | Description |
|----------|-------------|
| [Overview](docs/architecture/overview.md) | High-level platform overview |
| [AWS Architecture](docs/architecture/aws-architecture.md) | AWS infrastructure design |
| [Azure Architecture](docs/architecture/azure-architecture.md) | Azure infrastructure design |
| [GCP Architecture](docs/architecture/gcp-architecture.md) | GCP infrastructure design |
| [Kubernetes Architecture](docs/architecture/kubernetes-architecture.md) | K8s platform design |
| [Networking](docs/architecture/networking-architecture.md) | Network topology |
| [Security](docs/architecture/security-architecture.md) | Security architecture |
| [Observability](docs/architecture/observability-architecture.md) | Monitoring & tracing |
| [Disaster Recovery](docs/architecture/disaster-recovery.md) | DR strategy |
| [Multi-Region Design](docs/architecture/multi-region-design.md) | Global deployment |

### ⚙️ Setup Guides
| Document | Description |
|----------|-------------|
| [Prerequisites](docs/setup/prerequisites.md) | Required tools & accounts |
| [Local Development](docs/setup/local-development.md) | Local dev environment |
| [Docker Setup](docs/setup/docker-setup.md) | Docker/Compose local workflow |
| [Kubernetes Setup](docs/setup/kubernetes-setup.md) | K8s cluster setup |
| [Terraform Setup](docs/setup/terraform-setup.md) | IaC setup |
| [AWS Setup](docs/setup/aws-setup.md) | AWS environment |
| [Azure Setup](docs/setup/azure-setup.md) | Azure environment |
| [GCP Setup](docs/setup/gcp-setup.md) | GCP environment |
| [ArgoCD Setup](docs/setup/argocd-setup.md) | GitOps setup |
| [Monitoring Setup](docs/setup/monitoring-setup.md) | Observability stack |

### 🔄 CI/CD
| Document | Description |
|----------|-------------|
| [GitHub Actions](docs/cicd/github-actions.md) | Workflow documentation |
| [Jenkins](docs/cicd/jenkins.md) | Jenkins pipeline docs |
| [Deployment Strategies](docs/cicd/deployment-strategies.md) | Blue/green, canary |
| [Rollback Strategies](docs/cicd/rollback-strategies.md) | Rollback procedures |

### 📊 SRE
| Document | Description |
|----------|-------------|
| [SLIs/SLOs/SLAs](docs/sre/slis-slos-slas.md) | Service level objectives |
| [Incident Management](docs/sre/incident-management.md) | Incident response |
| [Alerting Strategy](docs/sre/alerting-strategy.md) | Alert configuration |
| [Error Budget](docs/sre/error-budget.md) | Error budget tracking |
| [Chaos Engineering](docs/sre/chaos-engineering.md) | Chaos experiments |

### 🔒 Security
| Document | Description |
|----------|-------------|
| [DevSecOps](docs/security/devsecops.md) | Security in CI/CD |
| [IAM Strategy](docs/security/iam-strategy.md) | Identity management |
| [Secrets Management](docs/security/secrets-management.md) | Vault integration |
| [Runtime Security](docs/security/runtime-security.md) | Falco, OPA |
| [Compliance](docs/security/compliance.md) | PCI-DSS, SOC2 |

### 📚 Runbooks
| Runbook | Trigger |
|---------|---------|
| [Cluster Failure](runbooks/cluster-failure.md) | K8s cluster down |
| [Node Failure](runbooks/node-failure.md) | Node not ready |
| [Pod CrashLoop](runbooks/pod-crashloop.md) | Pod crash looping |
| [High Latency](runbooks/high-latency.md) | P99 > SLO threshold |
| [Database Failover](runbooks/database-failover.md) | DB primary failure |
| [Ingress Failure](runbooks/ingress-failure.md) | Ingress not routing |
| [DNS Failure](runbooks/dns-failure.md) | DNS resolution failure |

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Frontend | Next.js 14, React 18, TypeScript | SSR ecommerce UI |
| API Gateway | Kong Gateway | Rate limiting, auth, routing |
| Service Mesh | Istio 1.20 | mTLS, traffic management |
| Container Platform | Kubernetes 1.29 | Container orchestration |
| AWS Compute | EKS, EC2, Lambda | AWS workloads |
| Azure Compute | AKS, VMs, Functions | Azure workloads |
| GCP Compute | GKE, GCE, Cloud Run | GCP workloads |
| IaC | Terraform 1.7 | Infrastructure as Code |
| GitOps | ArgoCD 2.10 | Continuous deployment |
| CI/CD | GitHub Actions, Jenkins | Build & test pipelines |
| Monitoring | Prometheus, Grafana | Metrics & dashboards |
| Logging | Loki, ELK Stack | Log aggregation |
| Tracing | Jaeger, Tempo | Distributed tracing |
| Security | Vault, Falco, Kyverno | Secrets & runtime security |
| Databases | Aurora, CosmosDB, Spanner | Multi-cloud databases |
| Cache | Redis Cluster | Session & object cache |
| Message Queue | Kafka, SQS, Pub/Sub | Async messaging |
| Search | Elasticsearch, OpenSearch | Product search |
| CDN | CloudFront, Azure CDN, Cloud CDN | Global content delivery |

---

## Environments

| Environment | Purpose | Cloud | Auto-Deploy |
|-------------|---------|-------|-------------|
| DEV | Development & testing | AWS us-east-1 | On PR merge |
| STAGING | Pre-production validation | AWS + Azure | On release tag |
| PRODUCTION | Live traffic | AWS + Azure + GCP | Manual approval |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development workflow, coding standards, and PR process.

---

*Built with ❤️ for enterprise-scale reliability, security, and performance.*
