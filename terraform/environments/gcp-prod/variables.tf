# ============================================================
# GCP Production Environment — Variables, Providers, Backend
# ============================================================

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "vpn_cidr" {
  description = "Corporate VPN CIDR for master authorized networks"
  type        = string
  default     = "10.0.0.0/8"
}

variable "db_root_password" {
  description = "Cloud SQL root password"
  type        = string
  sensitive   = true
}
