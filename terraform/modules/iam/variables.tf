# ============================================================
# Terraform IAM Module — Variables & Outputs
# ============================================================

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  type        = string
}

variable "assets_bucket_name" {
  description = "Name of the S3 assets bucket"
  type        = string
}

variable "service_accounts" {
  description = "Map of service name to K8s service account config"
  type = map(object({
    namespace       = string
    service_account = string
  }))
  default = {
    "auth-service" = {
      namespace       = "nexacommerce-prod"
      service_account = "auth-service"
    }
    "product-service" = {
      namespace       = "nexacommerce-prod"
      service_account = "product-service"
    }
    "order-service" = {
      namespace       = "nexacommerce-prod"
      service_account = "order-service"
    }
    "payment-service" = {
      namespace       = "nexacommerce-prod"
      service_account = "payment-service"
    }
    "notification-service" = {
      namespace       = "nexacommerce-prod"
      service_account = "notification-service"
    }
  }
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
