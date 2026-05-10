# Terraform Setup Guide — NexaCommerce

## Overview
NexaCommerce uses **modular Terraform** to manage infrastructure across AWS, Azure, and GCP. Each environment (dev, staging, prod) has its own state and configuration.

---

## Module Structure

```
terraform/
├── modules/
│   ├── networking/     # VPC, subnets, NAT, flow logs
│   ├── eks/            # EKS cluster, node groups, IRSA
│   ├── databases/      # Aurora PostgreSQL, ElastiCache Redis
│   ├── iam/            # IRSA roles per microservice
│   ├── security/       # KMS, WAF, GuardDuty, SecurityHub
│   └── storage/        # S3 buckets, ECR repositories
└── environments/
    ├── dev/            # Dev environment (smaller, cheaper)
    ├── staging/        # Staging environment (prod-like)
    └── prod/           # Production (full HA, multi-AZ)
```

---

## Prerequisites

```bash
# Install Terraform
brew install terraform          # macOS
choco install terraform         # Windows
sudo apt install terraform      # Ubuntu

# Verify version
terraform version               # Must be >= 1.7.0

# Install AWS CLI and configure
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region: us-east-1
```

---

## Bootstrap Remote State (First Time Only)

Before using Terraform, create the S3 backend and DynamoDB lock table:

```bash
# Run bootstrap script
bash scripts/terraform/bootstrap-state.sh

# What it creates:
# - S3 bucket: nexacommerce-tf-state (versioned, encrypted)
# - DynamoDB table: nexacommerce-tf-locks
# - KMS key: alias/nexacommerce-terraform-state
```

---

## Deploy DEV Environment

```bash
cd terraform/environments/dev

# Initialize (downloads providers + modules)
terraform init

# Review planned changes
terraform plan \
  -var="db_master_password=your-dev-password" \
  -var="redis_auth_token=your-redis-token-16chars"

# Apply changes
terraform apply \
  -var="db_master_password=your-dev-password" \
  -var="redis_auth_token=your-redis-token-16chars"

# Configure kubectl
aws eks update-kubeconfig \
  --name nexacommerce-dev \
  --region us-east-1
```

---

## Deploy STAGING Environment

```bash
cd terraform/environments/staging

terraform init
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"
```

---

## Deploy PRODUCTION Environment

```bash
cd terraform/environments/prod

terraform init

# Always plan first in prod
terraform plan \
  -var-file="prod.tfvars" \
  -out=tfplan

# Review plan carefully
terraform show tfplan

# Apply with explicit approval
terraform apply tfplan
```

---

## Module Usage Examples

### Networking Module

```hcl
module "networking" {
  source = "../../modules/networking"

  project            = "nexacommerce"
  environment        = "prod"
  vpc_cidr           = "10.0.0.0/16"
  az_count           = 3
  enable_nat_gateway = true
  enable_flow_logs   = true

  tags = { CostCenter = "engineering" }
}
```

### EKS Module

```hcl
module "eks" {
  source = "../../modules/eks"

  project            = "nexacommerce"
  environment        = "prod"
  kubernetes_version = "1.29"
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids
  kms_key_arn        = aws_kms_key.main.arn
}
```

---

## Secrets Management

**Never put secrets in `.tfvars` files committed to git.**

Use one of:

```bash
# Option 1: Environment variables
export TF_VAR_db_master_password="$(aws secretsmanager get-secret-value \
  --secret-id nexacommerce/prod/db-password \
  --query SecretString --output text)"

# Option 2: AWS Secrets Manager in CI/CD
# See .github/workflows/terraform-ci.yml

# Option 3: HashiCorp Vault
vault kv get -field=password secret/nexacommerce/prod/db
```

---

## Terraform Workflow in CI/CD

```
PR opened     → terraform fmt check + tflint + checkov
PR approved   → terraform plan (comment on PR)
Merge to main → terraform apply (dev auto)
Release tag   → terraform apply (staging, manual approval)
SRE approval  → terraform apply (prod, manual approval)
```

---

## Useful Commands

```bash
# Format all Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Show current state
terraform show

# List all resources
terraform state list

# Import existing resource
terraform import aws_s3_bucket.assets nexacommerce-assets-prod

# Destroy specific resource
terraform destroy -target=module.databases.aws_rds_cluster.main

# Unlock state (if locked)
terraform force-unlock <lock-id>
```

---

## Cost Estimates

| Environment | Monthly Cost (approx) |
|-------------|----------------------|
| DEV | ~$300/month |
| STAGING | ~$800/month |
| PRODUCTION | ~$8,000–15,000/month |

Use `infracost` for detailed estimates:
```bash
infracost breakdown --path terraform/environments/prod
```
