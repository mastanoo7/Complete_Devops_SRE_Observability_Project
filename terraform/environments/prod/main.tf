# ============================================================
# Production Environment — Main Terraform Configuration
# Orchestrates all modules for the production environment
# ============================================================

locals {
  environment = "prod"
  project     = "nexacommerce"
  aws_region  = "us-east-1"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
  }
}

# ── KMS Key for encryption ───────────────────────────────────
resource "aws_kms_key" "main" {
  description             = "${local.project}-${local.environment} encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-kms"
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.project}-${local.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# ── Networking Module ────────────────────────────────────────
module "networking" {
  source = "../../modules/networking"

  project            = local.project
  environment        = local.environment
  vpc_cidr           = var.vpc_cidr
  az_count           = 3
  enable_nat_gateway = true
  enable_flow_logs   = true

  tags = local.common_tags
}

# ── EKS Module ───────────────────────────────────────────────
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
  public_access_cidrs    = var.allowed_cidr_blocks

  node_groups = {
    system = {
      instance_types = ["m5.xlarge"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
      desired_size   = 3
      min_size       = 3
      max_size       = 6
      labels         = { "workload-type" = "system" }
      taints         = []
    }
    app-general = {
      instance_types = ["m5.2xlarge"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 100
      desired_size   = 6
      min_size       = 3
      max_size       = 30
      labels         = { "workload-type" = "general" }
      taints         = []
    }
    app-memory = {
      instance_types = ["r5.2xlarge"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 100
      desired_size   = 3
      min_size       = 3
      max_size       = 15
      labels         = { "workload-type" = "memory" }
      taints         = []
    }
    app-spot = {
      instance_types = ["m5.2xlarge", "m5a.2xlarge", "m4.2xlarge"]
      capacity_type  = "SPOT"
      disk_size      = 100
      desired_size   = 0
      min_size       = 0
      max_size       = 20
      labels         = { "workload-type" = "spot" }
      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  additional_map_roles = var.additional_eks_roles

  tags = local.common_tags
}

# ── Databases Module ─────────────────────────────────────────
module "databases" {
  source = "../../modules/databases"

  project     = local.project
  environment = local.environment

  vpc_id                     = module.networking.vpc_id
  data_subnet_ids            = module.networking.data_subnet_ids
  eks_node_security_group_id = module.eks.cluster_security_group_id
  kms_key_arn                = aws_kms_key.main.arn

  aurora_engine_version = "15.4"
  aurora_instance_class = "db.r6g.2xlarge"
  aurora_reader_count   = 2
  database_name         = "nexacommerce"
  master_username       = var.db_master_username
  master_password       = var.db_master_password
  backup_retention_days = 35

  redis_node_type       = "cache.r6g.xlarge"
  redis_num_cache_nodes = 3
  redis_auth_token      = var.redis_auth_token

  tags = local.common_tags
}

# ── ECR Repositories ─────────────────────────────────────────
resource "aws_ecr_repository" "services" {
  for_each = toset([
    "frontend", "api-gateway", "auth-service", "product-service",
    "cart-service", "order-service", "payment-service",
    "inventory-service", "search-service", "recommendation-service",
    "notification-service", "admin-service"
  ])

  name                 = "${local.project}/${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.main.arn
  }

  tags = merge(local.common_tags, {
    Name = "${local.project}/${each.key}"
  })
}

resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ── S3 Buckets ───────────────────────────────────────────────
resource "aws_s3_bucket" "assets" {
  bucket = "${local.project}-assets-${local.environment}-${data.aws_caller_identity.current.account_id}"
  tags   = merge(local.common_tags, { Name = "assets" })
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}
