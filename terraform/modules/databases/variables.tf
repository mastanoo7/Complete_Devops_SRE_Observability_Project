# ============================================================
# Terraform Databases Module — Variables
# ============================================================

variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where databases will be deployed"
  type        = string
}

variable "data_subnet_ids" {
  description = "List of data subnet IDs for database placement"
  type        = list(string)
}

variable "eks_node_security_group_id" {
  description = "Security group ID of EKS nodes (for DB ingress)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption at rest"
  type        = string
}

# ── Aurora Variables ─────────────────────────────────────────
variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "aurora_instance_class" {
  description = "Instance class for Aurora instances"
  type        = string
  default     = "db.r6g.xlarge"
}

variable "aurora_reader_count" {
  description = "Number of Aurora read replicas"
  type        = number
  default     = 2
}

variable "database_name" {
  description = "Name of the default database"
  type        = string
  default     = "nexacommerce"
}

variable "master_username" {
  description = "Master username for Aurora"
  type        = string
  default     = "nexacommerce"
  sensitive   = true
}

variable "master_password" {
  description = "Master password for Aurora (use Secrets Manager in prod)"
  type        = string
  sensitive   = true
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 35
}

# ── Redis Variables ──────────────────────────────────────────
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.r6g.large"
}

variable "redis_num_cache_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
  default     = 3
}

variable "redis_auth_token" {
  description = "Auth token for Redis (min 16 chars)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
