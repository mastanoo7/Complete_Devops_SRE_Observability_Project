# ============================================================
# Terraform EKS Module — Variables
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

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for load balancers"
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encrypting K8s secrets"
  type        = string
}

variable "endpoint_public_access" {
  description = "Enable public access to the EKS API endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to access the public EKS endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    disk_size      = number
    desired_size   = number
    min_size       = number
    max_size       = number
    labels         = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  default = {
    system = {
      instance_types = ["m5.xlarge"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
      desired_size   = 3
      min_size       = 3
      max_size       = 6
      labels         = { "workload-type" = "system" }
      taints         = []
    }
    app-general = {
      instance_types = ["m5.2xlarge"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 100
      desired_size   = 6
      min_size       = 3
      max_size       = 30
      labels         = { "workload-type" = "general" }
      taints         = []
    }
    app-spot = {
      instance_types = ["m5.2xlarge", "m5a.2xlarge", "m4.2xlarge"]
      capacity_type  = "SPOT"
      disk_size      = 100
      desired_size   = 0
      min_size       = 0
      max_size       = 20
      labels         = { "workload-type" = "spot" }
      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }
}

variable "addon_versions" {
  description = "EKS add-on versions"
  type = object({
    vpc_cni    = string
    coredns    = string
    kube_proxy = string
    ebs_csi    = string
  })
  default = {
    vpc_cni    = "v1.16.0-eksbuild.1"
    coredns    = "v1.11.1-eksbuild.4"
    kube_proxy = "v1.29.0-eksbuild.1"
    ebs_csi    = "v1.28.0-eksbuild.1"
  }
}

variable "additional_map_roles" {
  description = "Additional IAM roles to add to aws-auth ConfigMap"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "additional_map_users" {
  description = "Additional IAM users to add to aws-auth ConfigMap"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
