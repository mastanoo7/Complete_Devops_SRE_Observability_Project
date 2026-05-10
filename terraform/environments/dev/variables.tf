# ============================================================
# DEV Environment — Variables, Backend, Providers
# ============================================================

variable "db_master_username" {
  description = "Master username for Aurora PostgreSQL"
  type        = string
  sensitive   = true
  default     = "nexacommerce"
}

variable "db_master_password" {
  description = "Master password for Aurora PostgreSQL"
  type        = string
  sensitive   = true
}

variable "redis_auth_token" {
  description = "Auth token for ElastiCache Redis"
  type        = string
  sensitive   = true
}
