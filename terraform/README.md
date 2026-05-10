# Terraform — NexaCommerce Multi-Cloud Infrastructure

## Overview
Modular Terraform code for deploying NexaCommerce across **AWS**, **Azure**, and **GCP**.

---

## Directory Structure

```
terraform/
├── modules/                    # Reusable modules
│   ├── networking/             # AWS VPC, subnets, NAT, flow logs
│   ├── eks/                    # AWS EKS cluster + node groups + IRSA
│   ├── databases/              # AWS Aurora PostgreSQL + ElastiCache Redis
│   ├── iam/                    # AWS IRSA roles per microservice
│   ├── aks/                    # Azure AKS cluster + node pools
│   ├── azure-networking/       # Azure VNet, subnets, NSGs, NAT
│   ├── gke/                    # GCP GKE cluster + node pools
│   └── gcp-networking/         # GCP VPC, subnets, Cloud NAT, firewall
│
└── environments/
    ├── prod/                   # AWS Production (EKS + Aurora + Redis)
    ├── dev/                    # AWS Development (smaller instances)
    ├── azure-prod/             # Azure Production (AKS + CosmosDB + Redis)
    └── gcp-prod/               # GCP Production (GKE + Cloud SQL + Memorystore)
```

---

## Module Reference

### AWS Modules

#### [`modules/networking`](modules/networking/)
Creates AWS VPC with public/private/data subnets across 3 AZs, NAT Gateways, and VPC Flow Logs.

```hcl
module "networking" {
  source             = "../../modules/networking"
  project            = "nexacommerce"
  environment        = "prod"
  vpc_cidr           = "10.0.0.0/16"
  az_count           = 3
  enable_nat_gateway = true
  enable_flow_logs   = true
}
```

**Outputs**: `vpc_id`, `private_subnet_ids`, `public_subnet_ids`, `data_subnet_ids`

---

#### [`modules/eks`](modules/eks/)
Creates EKS 1.29 cluster with managed node groups, IRSA OIDC provider, and core add-ons.

```hcl
module "eks" {
  source             = "../../modules/eks"
  project            = "nexacommerce"
  environment        = "prod"
  kubernetes_version = "1.29"
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids
  kms_key_arn        = aws_kms_key.main.arn
}
```

**Outputs**: `cluster_name`, `cluster_endpoint`, `oidc_provider_arn`

---

#### [`modules/databases`](modules/databases/)
Creates Aurora PostgreSQL (multi-AZ) and ElastiCache Redis (cluster mode).

```hcl
module "databases" {
  source                     = "../../modules/databases"
  project                    = "nexacommerce"
  environment                = "prod"
  vpc_id                     = module.networking.vpc_id
  data_subnet_ids            = module.networking.data_subnet_ids
  eks_node_security_group_id = module.eks.cluster_security_group_id
  kms_key_arn                = aws_kms_key.main.arn
  master_password            = var.db_master_password
  redis_auth_token           = var.redis_auth_token
}
```

**Outputs**: `aurora_cluster_endpoint`, `aurora_reader_endpoint`, `redis_primary_endpoint`

---

#### [`modules/iam`](modules/iam/)
Creates per-service IRSA IAM roles with least-privilege policies.

```hcl
module "iam" {
  source             = "../../modules/iam"
  project            = "nexacommerce"
  environment        = "prod"
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  kms_key_arn        = aws_kms_key.main.arn
  assets_bucket_name = aws_s3_bucket.assets.bucket
}
```

---

### Azure Modules

#### [`modules/azure-networking`](modules/azure-networking/)
Creates Azure VNet with AKS subnets, data subnet, NSGs, and NAT Gateway.

```hcl
module "networking" {
  source      = "../../modules/azure-networking"
  project     = "nexacommerce"
  environment = "prod"
  location    = "westeurope"
  vnet_cidr   = "10.10.0.0/16"
}
```

**Outputs**: `vnet_id`, `aks_app_subnet_id`, `data_subnet_id`

---

#### [`modules/aks`](modules/aks/)
Creates AKS 1.29 cluster with system + app + spot node pools, Workload Identity, and Azure Monitor.

```hcl
module "aks" {
  source                = "../../modules/aks"
  project               = "nexacommerce"
  environment           = "prod"
  location              = "westeurope"
  subnet_id             = module.networking.aks_app_subnet_id
  container_registry_id = azurerm_container_registry.main.id
}
```

**Outputs**: `cluster_name`, `kube_config`, `oidc_issuer_url`

---

### GCP Modules

#### [`modules/gcp-networking`](modules/gcp-networking/)
Creates GCP VPC with GKE subnet (secondary ranges for pods/services), Cloud NAT, and firewall rules.

```hcl
module "networking" {
  source      = "../../modules/gcp-networking"
  project     = "nexacommerce"
  project_id  = var.gcp_project_id
  environment = "prod"
  region      = "us-central1"
}
```

**Outputs**: `network_name`, `gke_subnet_name`, `pods_range_name`, `services_range_name`

---

#### [`modules/gke`](modules/gke/)
Creates GKE Autopilot-compatible cluster with Workload Identity, Binary Authorization, and managed Prometheus.

```hcl
module "gke" {
  source              = "../../modules/gke"
  project             = "nexacommerce"
  project_id          = var.gcp_project_id
  environment         = "prod"
  region              = "us-central1"
  network             = module.networking.network_name
  subnetwork          = module.networking.gke_subnet_name
  pods_range_name     = module.networking.pods_range_name
  services_range_name = module.networking.services_range_name
}
```

**Outputs**: `cluster_name`, `cluster_endpoint`, `workload_identity_pool`

---

## Environments

| Environment | Cloud | Path | Auto-Deploy |
|-------------|-------|------|-------------|
| `prod` | AWS | `environments/prod/` | Manual (SRE approval) |
| `dev` | AWS | `environments/dev/` | Auto on merge to main |
| `azure-prod` | Azure | `environments/azure-prod/` | Manual (SRE approval) |
| `gcp-prod` | GCP | `environments/gcp-prod/` | Manual (SRE approval) |

---

## Quick Start

```bash
# AWS Production
cd terraform/environments/prod
terraform init
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"

# Azure Production
cd terraform/environments/azure-prod
terraform init
terraform plan
terraform apply

# GCP Production
cd terraform/environments/gcp-prod
terraform init
terraform plan -var="gcp_project_id=your-project"
terraform apply -var="gcp_project_id=your-project"
```

See [Terraform Setup Guide](../docs/setup/terraform-setup.md) for full instructions.

---

## Provider Versions

| Provider | Version | Cloud |
|----------|---------|-------|
| `hashicorp/aws` | `~> 5.40` | AWS |
| `hashicorp/azurerm` | `~> 3.95` | Azure |
| `hashicorp/google` | `~> 5.20` | GCP |
| `hashicorp/kubernetes` | `~> 2.27` | All |
| `hashicorp/helm` | `~> 2.12` | All |
| `hashicorp/terraform` | `>= 1.7.0` | All |
