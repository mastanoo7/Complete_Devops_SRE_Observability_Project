# ============================================================
# Terraform GKE Module — Variables
# ============================================================

variable "project" {
  description = "Project name used for resource naming and labels"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
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

variable "region" {
  description = "GCP region for the GKE cluster"
  type        = string
  default     = "us-central1"
}

variable "kubernetes_version" {
  description = "Minimum Kubernetes version for GKE"
  type        = string
  default     = "1.29"
}

variable "network" {
  description = "VPC network name or self_link"
  type        = string
}

variable "subnetwork" {
  description = "VPC subnetwork name or self_link"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary IP range name for pods"
  type        = string
  default     = "pods"
}

variable "services_range_name" {
  description = "Secondary IP range name for services"
  type        = string
  default     = "services"
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for GKE master nodes (private cluster)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "List of CIDR blocks authorized to access the master"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "All (restrict in production)"
    }
  ]
}

variable "system_node_pool" {
  description = "System node pool configuration"
  type = object({
    machine_type       = string
    disk_size_gb       = number
    initial_node_count = number
    min_node_count     = number
    max_node_count     = number
  })
  default = {
    machine_type       = "e2-standard-4"
    disk_size_gb       = 50
    initial_node_count = 1
    min_node_count     = 1
    max_node_count     = 3
  }
}

variable "app_node_pool" {
  description = "Application node pool configuration"
  type = object({
    machine_type       = string
    disk_size_gb       = number
    initial_node_count = number
    min_node_count     = number
    max_node_count     = number
  })
  default = {
    machine_type       = "n2-standard-8"
    disk_size_gb       = 100
    initial_node_count = 3
    min_node_count     = 3
    max_node_count     = 30
  }
}

variable "spot_node_pool" {
  description = "Spot node pool configuration"
  type = object({
    machine_type   = string
    max_node_count = number
  })
  default = {
    machine_type   = "n2-standard-8"
    max_node_count = 20
  }
}

variable "labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}
