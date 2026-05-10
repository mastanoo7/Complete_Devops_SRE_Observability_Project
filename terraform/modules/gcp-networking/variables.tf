# ============================================================
# GCP Networking Module — Variables & Outputs
# ============================================================

variable "project" {
  description = "Project name for resource naming"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "gke_subnet_cidr" {
  description = "CIDR for GKE node subnet"
  type        = string
  default     = "10.20.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR for GKE pods"
  type        = string
  default     = "10.21.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR for GKE services"
  type        = string
  default     = "10.22.0.0/20"
}

variable "data_subnet_cidr" {
  description = "CIDR for data subnet (Cloud SQL, Memorystore)"
  type        = string
  default     = "10.20.16.0/24"
}

variable "master_ipv4_cidr_block" {
  description = "CIDR for GKE master nodes"
  type        = string
  default     = "172.16.0.0/28"
}

variable "labels" {
  description = "Additional labels"
  type        = map(string)
  default     = {}
}
