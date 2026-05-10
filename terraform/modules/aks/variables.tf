# ============================================================
# Terraform AKS Module — Variables
# ============================================================

variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for the AKS cluster"
  type        = string
  default     = "westeurope"
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.29"
}

variable "subnet_id" {
  description = "Azure subnet ID for AKS nodes"
  type        = string
}

variable "container_registry_id" {
  description = "Azure Container Registry resource ID for AcrPull role"
  type        = string
}

variable "admin_group_object_ids" {
  description = "Azure AD group object IDs for cluster admin access"
  type        = list(string)
  default     = []
}

variable "system_node_pool" {
  description = "System node pool configuration"
  type = object({
    vm_size         = string
    node_count      = number
    min_count       = number
    max_count       = number
    os_disk_size_gb = number
  })
  default = {
    vm_size         = "Standard_D4s_v3"
    node_count      = 3
    min_count       = 3
    max_count       = 6
    os_disk_size_gb = 50
  }
}

variable "app_node_pool" {
  description = "Application node pool configuration"
  type = object({
    vm_size         = string
    node_count      = number
    min_count       = number
    max_count       = number
    os_disk_size_gb = number
  })
  default = {
    vm_size         = "Standard_D8s_v3"
    node_count      = 3
    min_count       = 3
    max_count       = 30
    os_disk_size_gb = 100
  }
}

variable "spot_node_pool" {
  description = "Spot node pool configuration"
  type = object({
    vm_size   = string
    max_count = number
  })
  default = {
    vm_size   = "Standard_D8s_v3"
    max_count = 20
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
