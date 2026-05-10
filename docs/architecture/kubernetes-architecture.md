# Kubernetes Architecture — NexaCommerce

## Overview
NexaCommerce runs on Kubernetes 1.29 across three clouds (EKS, AKS, GKE). This document covers the platform design, namespace strategy, resource management, and operational patterns.

---

## Cluster Topology

| Cluster | Cloud | Region | Purpose |
|---------|-------|--------|---------|
| `nexacommerce-prod-aws` | EKS | us-east-1 | Primary production |
| `nexacommerce-prod-azure` | AKS | west-europe | Secondary production |
| `nexacommerce-prod-gcp` | GKE | us-central1 | Tertiary production |
| `nexacommerce-staging` | EKS | us-east-1 | Staging environment |
| `nexacommerce-dev` | EKS | us-east-1 | Development environment |

---

## Namespace Strategy

```
nexacommerce-prod/          # Production workloads
nexacommerce-staging/       # Staging workloads
nexacommerce-dev/           # Development workloads
istio-system/               # Istio control plane
kong/                       # Kong API Gateway
argocd/                     # ArgoCD GitOps
monitoring/                 # Prometheus, Grafana, Loki
logging/                    # Fluentbit, Elasticsearch
security/                   # Vault agent, Falco, Kyverno
cert-manager/               # TLS certificate management
kube-system/                # Core K8s components
```

---

## Resource Quotas per Namespace

### Production Namespace

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: nexacommerce-prod
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    pods: "200"
    services: "50"
    persistentvolumeclaims: "30"
```

### Per-Service Resource Limits

| Service | CPU Request | CPU Limit | Mem Request | Mem Limit | Replicas |
|---------|------------|-----------|-------------|-----------|---------|
| frontend | 250m | 1000m | 256Mi | 1Gi | 3–20 |
| auth-service | 250m | 500m | 256Mi | 512Mi | 3–15 |
| product-service | 500m | 2000m | 512Mi | 2Gi | 3–20 |
| cart-service | 250m | 500m | 256Mi | 512Mi | 3–15 |
| order-service | 500m | 2000m | 512Mi | 2Gi | 3–15 |
| payment-service | 250m | 1000m | 256Mi | 1Gi | 3–10 |
| inventory-service | 250m | 1000m | 256Mi | 1Gi | 3–10 |
| search-service | 500m | 2000m | 1Gi | 4Gi | 3–20 |
| recommendation-service | 1000m | 4000m | 2Gi | 8Gi | 2–8 |
| notification-service | 250m | 500m | 256Mi | 512Mi | 2–10 |

---

## Autoscaling Strategy

### Horizontal Pod Autoscaler (HPA)

```yaml
# Example: product-service HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"
```

### Vertical Pod Autoscaler (VPA)

Used for right-sizing in dev/staging:
```yaml
updatePolicy:
  updateMode: "Auto"   # dev/staging
  updateMode: "Off"    # production (recommendations only)
```

### Cluster Autoscaler

```yaml
# Node group scaling triggers
scale-up:   CPU > 70% OR Memory > 80% for 3 minutes
scale-down: CPU < 30% AND Memory < 40% for 10 minutes
cooldown:   5 minutes after scale-up
```

---

## Pod Disruption Budgets

All production services have PDBs to ensure availability during node drains:

```yaml
# Minimum 2 pods always available
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: product-service
```

---

## Affinity & Anti-Affinity Rules

```yaml
# Spread pods across AZs (all services)
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app
              operator: In
              values: [product-service]
        topologyKey: topology.kubernetes.io/zone

# Payment service: dedicated nodes only
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
      - matchExpressions:
          - key: workload-type
            operator: In
            values: [payment-pci]
```

---

## Storage Classes

| StorageClass | Provisioner | Type | Use Case |
|-------------|------------|------|---------|
| `fast-ssd` | ebs.csi.aws.com | gp3, 3000 IOPS | Databases |
| `standard` | ebs.csi.aws.com | gp2 | General workloads |
| `efs-shared` | efs.csi.aws.com | EFS | Shared config, ML models |

---

## Network Policies

All namespaces use **default-deny** with explicit allow rules:

```yaml
# Default deny all ingress/egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

Explicit allows:
- `frontend` → `api-gateway` (port 8080)
- `api-gateway` → all services (port 8080)
- `order-service` → `payment-service` (port 8080)
- All services → `monitoring` namespace (port 9090)
- All services → `kube-dns` (port 53)

---

## GitOps with Kustomize

```
kubernetes/
├── base/                    # Base manifests (all environments)
│   ├── frontend/
│   ├── auth-service/
│   ├── product-service/
│   └── ...
└── overlays/
    ├── dev/                 # Dev patches (lower resources, 1 replica)
    ├── staging/             # Staging patches (medium resources)
    └── prod/                # Prod patches (full resources, HPA)
        ├── kustomization.yaml
        ├── replicas-patch.yaml
        ├── resources-patch.yaml
        └── hpa-patch.yaml
```

---

## Health Checks

All services implement:

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3

startupProbe:
  httpGet:
    path: /health/startup
    port: 8080
  failureThreshold: 30
  periodSeconds: 10
```

---

## Related Documents

- [Kubernetes Cluster Diagram](../diagrams/kubernetes-cluster.mmd)
- [Service Mesh Architecture](../diagrams/service-mesh.mmd)
- [Kubernetes Setup Guide](../setup/kubernetes-setup.md)
- [Terraform EKS Module](../../terraform/modules/eks/)
