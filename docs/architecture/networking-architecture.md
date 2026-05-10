# Networking Architecture — NexaCommerce

## Overview
NexaCommerce uses a **multi-layer, defense-in-depth** network architecture spanning three clouds with CloudFlare as the global edge.

---

## Global Traffic Flow

```
User Request
    ↓
CloudFlare (DNS + CDN + WAF + DDoS)
    ↓ (health-check based routing)
    ├── AWS ALB (us-east-1)     → EKS
    ├── Azure Front Door        → AKS
    └── GCP Global LB           → GKE
         ↓
    Kong API Gateway
         ↓
    Istio Ingress Gateway
         ↓
    Microservices (mTLS)
```

---

## CloudFlare Configuration

### DNS & Load Balancing
```yaml
Load Balancer:
  name: api.nexacommerce.com
  pools:
    - aws-us-east-1:    weight: 40, health_check: /health
    - azure-westeurope: weight: 35, health_check: /health
    - gcp-us-central1:  weight: 25, health_check: /health
  steering_policy: dynamic_latency
  session_affinity: cookie (30min)

Failover:
  unhealthy_threshold: 2 consecutive failures
  health_check_interval: 30s
  failover_time: < 30s
```

### WAF Rules
```yaml
Rules:
  - OWASP Core Rule Set 3.3
  - Rate limiting: 1000 req/min per IP
  - Bot protection: JS challenge for suspicious IPs
  - DDoS: Auto-mitigation at L3/L4/L7
  - Geo-blocking: Configurable per region
```

---

## AWS Networking

### VPC Architecture
```
VPC: 10.0.0.0/16 (us-east-1)
├── Public Subnets (ALB, NAT)
│   ├── 10.0.1.0/24 (AZ-a)
│   ├── 10.0.2.0/24 (AZ-b)
│   └── 10.0.3.0/24 (AZ-c)
├── Private Subnets (EKS nodes)
│   ├── 10.0.11.0/24 (AZ-a)
│   ├── 10.0.12.0/24 (AZ-b)
│   └── 10.0.13.0/24 (AZ-c)
└── Data Subnets (RDS, Redis)
    ├── 10.0.21.0/24 (AZ-a)
    ├── 10.0.22.0/24 (AZ-b)
    └── 10.0.23.0/24 (AZ-c)
```

### Security Groups
| SG | Inbound | Outbound |
|----|---------|----------|
| ALB | 443/80 from 0.0.0.0/0 | 8080 to EKS nodes |
| EKS nodes | All from ALB + EKS nodes | All |
| RDS | 5432 from EKS nodes | None |
| Redis | 6379 from EKS nodes | None |

---

## Azure Networking

### VNet Architecture
```
VNet: 10.10.0.0/16 (westeurope)
├── AKS System: 10.10.1.0/24
├── AKS App:    10.10.2.0/22
├── Data:       10.10.10.0/24
└── AppGW:      10.10.20.0/24
```

---

## GCP Networking

### VPC Architecture
```
VPC: nexacommerce-prod-vpc (global)
├── GKE Nodes:    10.20.0.0/20 (us-central1)
│   ├── Pods:     10.21.0.0/16 (secondary)
│   └── Services: 10.22.0.0/20 (secondary)
└── Data:         10.20.16.0/24 (us-central1)
```

---

## Service Mesh (Istio)

### mTLS Configuration
- **Mode**: STRICT (all namespaces in production)
- **Certificate rotation**: Every 24 hours (Citadel)
- **SPIFFE/SVID**: Per-service identity

### Traffic Management
- **Circuit breakers**: Per service via DestinationRules
- **Retries**: Configurable per VirtualService
- **Timeouts**: Service-specific (payment: 30s, auth: 10s)
- **Load balancing**: LEAST_CONN for stateful, ROUND_ROBIN for stateless

---

## Network Policies (Kubernetes)

All namespaces use **default-deny** with explicit allow rules:

```
nexacommerce-prod:
  Default: DENY all ingress + egress
  Allow:
    - Kong → all services (port 8080-8090)
    - Services → databases (5432, 6379, 9092)
    - Services → monitoring (9090)
    - All → kube-dns (53)
    - All → external HTTPS (443)
    - Istio control plane ↔ all pods
```

---

## Related Documents
- [High-Level Architecture](../diagrams/high-level-architecture.mmd)
- [AWS Infrastructure](aws-architecture.md)
- [Azure Architecture](azure-architecture.md)
- [GCP Architecture](gcp-architecture.md)
- [Service Mesh Diagram](../diagrams/service-mesh.mmd)
