# ============================================================
# Azure Networking Module — Variables & Outputs
# ============================================================

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "vnet_cidr" {
  description = "CIDR block for the Virtual Network"
  type        = string
  default     = "10.10.0.0/16"
}

variable "aks_system_subnet_cidr" {
  description = "CIDR for AKS system node pool subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "aks_app_subnet_cidr" {
  description = "CIDR for AKS app node pool subnet"
  type        = string
  default     = "10.10.2.0/22"
}

variable "data_subnet_cidr" {
  description = "CIDR for data subnet (databases, cache)"
  type        = string
  default     = "10.10.10.0/24"
}

variable "appgw_subnet_cidr" {
  description = "CIDR for Application Gateway subnet"
  type        = string
  default     = "10.10.20.0/24"
}

variable "enable_network_watcher" {
  description = "Enable Azure Network Watcher"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
