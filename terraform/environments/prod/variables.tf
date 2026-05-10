# ============================================================
# Production Environment — Variables
# ============================================================

variable "vpc_cidr" {
  description = "CIDR block for the production VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_cidr_blocks" {
  description = "CIDRs allowed to access the EKS public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_master_username" {
  description = "Master username for Aurora PostgreSQL"
  type        = string
  sensitive   = true
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

variable "additional_eks_roles" {
  description = "Additional IAM roles to add to EKS aws-auth"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}
