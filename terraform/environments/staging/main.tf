# ============================================================
# Staging Environment — Main Terraform Configuration
# Production-like config with reduced scale for pre-prod testing
# ============================================================

locals {
  environment = "staging"
  project     = "nexacommerce"
  aws_region  = "us-east-1"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = "platform-team"
  }
}

# ── KMS Key ──────────────────────────────────────────────
resource "aws_kms_key" "main" {
  description             = "${local.project}-${local.environment} encryption key"
  deletion_window_in_days = 14
  enable_key_rotation     = true
  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-kms"
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.project}-${local.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# ── Networking ───────────────────────────────────────────
module "networking" {
  source = "../../modules/networking"

  project            = local.project
  environment        = local.environment
  vpc_cidr           = "10.1.0.0/16"
  az_count           = 3
  enable_nat_gateway = true
  enable_flow_logs   = true

  tags = local.common_tags
}

# ── EKS ──────────────────────────────────────────────────
module "eks" {
  source = "../../modules/eks"

  project            = local.project
  environment        = local.environment
  kubernetes_version = "1.29"

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids
  kms_key_arn        = aws_kms_key.main.arn

  endpoint_public_access = true
  public_access_cidrs    = ["0.0.0.0/0"]

  # Staging: production-like but smaller
  node_groups = {
    system = {
      instance_types = ["m5.large"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
      desired_size   = 3
      min_size       = 3
      max_size       = 6
      labels         = { "workload-type" = "system" }
      taints         = []
    }
    app-general = {
      instance_types = ["m5.xlarge"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 100
      desired_size   = 3
      min_size       = 3
      max_size       = 15
      labels         = { "workload-type" = "general" }
      taints         = []
    }
    app-spot = {
      instance_types = ["m5.xlarge", "m5a.xlarge"]
      capacity_type  = "SPOT"
      disk_size      = 100
      desired_size   = 0
      min_size       = 0
      max_size       = 10
      labels         = { "workload-type" = "spot" }
      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  tags = local.common_tags
}

# ── Databases ────────────────────────────────────────────
module "databases" {
  source = "../../modules/databases"

  project     = local.project
  environment = local.environment

  vpc_id                     = module.networking.vpc_id
  data_subnet_ids            = module.networking.data_subnet_ids
  eks_node_security_group_id = module.eks.cluster_security_group_id
  kms_key_arn                = aws_kms_key.main.arn

  # Staging: smaller than prod but same engine version
  aurora_engine_version = "15.4"
  aurora_instance_class = "db.r6g.large"
  aurora_reader_count   = 1
  database_name         = "nexacommerce"
  master_username       = var.db_master_username
  master_password       = var.db_master_password
  backup_retention_days = 14

  redis_node_type       = "cache.r6g.large"
  redis_num_cache_nodes = 2
  redis_auth_token      = var.redis_auth_token

  tags = local.common_tags
}

# ── ECR Repositories ─────────────────────────────────────
resource "aws_ecr_repository" "services" {
  for_each = toset([
    "frontend", "api-gateway", "auth-service", "product-service",
    "cart-service", "order-service", "payment-service",
    "inventory-service", "search-service", "recommendation-service",
    "notification-service", "admin-service"
  ])

  name                 = "${local.project}/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.project}/${each.key}"
  })
}

data "aws_caller_identity" "current" {}
