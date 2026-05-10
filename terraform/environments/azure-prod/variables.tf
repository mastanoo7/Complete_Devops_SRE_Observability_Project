# ============================================================
# Azure Production Environment — Variables
# ============================================================

variable "aks_admin_group_ids" {
  description = "Azure AD group object IDs for AKS cluster admin"
  type        = list(string)
  default     = []
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access Key Vault"
  type        = list(string)
  default     = []
}

variable "db_admin_username" {
  description = "PostgreSQL Flexible Server admin username"
  type        = string
  sensitive   = true
  default     = "nexaadmin"
}

variable "db_admin_password" {
  description = "PostgreSQL Flexible Server admin password"
  type        = string
  sensitive   = true
}
