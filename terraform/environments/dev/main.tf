# ============================================================
# DEV Environment — Main Terraform Configuration
# Lightweight config for development (smaller instances, less HA)
# ============================================================

locals {
  environment = "dev"
  project     = "nexacommerce"
  aws_region  = "us-east-1"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    AutoShutdown = "true"
  }
}

# ── KMS Key ──────────────────────────────────────────────────
resource "aws_kms_key" "main" {
  description             = "${local.project}-${local.environment} encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-kms"
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.project}-${local.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# ── Networking ───────────────────────────────────────────────
module "networking" {
  source = "../../modules/networking"

  project            = local.project
  environment        = local.environment
  vpc_cidr           = "10.2.0.0/16"
  az_count           = 2
  enable_nat_gateway = true
  enable_flow_logs   = false   # Save cost in dev

  tags = local.common_tags
}

# ── EKS ──────────────────────────────────────────────────────
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

  # Smaller node groups for dev
  node_groups = {
    system = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 30
      desired_size   = 2
      min_size       = 2
      max_size       = 4
      labels         = { "workload-type" = "system" }
      taints         = []
    }
    app-general = {
      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
      disk_size      = 50
      desired_size   = 2
      min_size       = 2
      max_size       = 10
      labels         = { "workload-type" = "general" }
      taints         = []
    }
  }

  tags = local.common_tags
}

# ── Databases ────────────────────────────────────────────────
module "databases" {
  source = "../../modules/databases"

  project     = local.project
  environment = local.environment

  vpc_id                     = module.networking.vpc_id
  data_subnet_ids            = module.networking.data_subnet_ids
  eks_node_security_group_id = module.eks.cluster_security_group_id
  kms_key_arn                = aws_kms_key.main.arn

  # Smaller instances for dev
  aurora_engine_version = "15.4"
  aurora_instance_class = "db.t3.medium"
  aurora_reader_count   = 1
  database_name         = "nexacommerce"
  master_username       = var.db_master_username
  master_password       = var.db_master_password
  backup_retention_days = 7

  redis_node_type       = "cache.t3.micro"
  redis_num_cache_nodes = 1
  redis_auth_token      = var.redis_auth_token

  tags = local.common_tags
}
