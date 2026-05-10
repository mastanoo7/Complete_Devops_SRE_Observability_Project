# ============================================================
# Terraform AKS Module — Main (azurerm ~> 3.x compatible)
# Creates Azure Kubernetes Service cluster with node pools
# ============================================================

locals {
  cluster_name = "${var.project}-${var.environment}"

  common_tags = merge(var.tags, {
    Module      = "aks"
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project
  })
}

# ── Resource Group ────────────────────────────────────────
resource "azurerm_resource_group" "aks" {
  name     = "${local.cluster_name}-aks-rg"
  location = var.location
  tags     = local.common_tags
}

# ── Log Analytics Workspace ───────────────────────────────
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "${local.cluster_name}-logs"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# ── AKS Cluster ───────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "main" {
  name                = local.cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = local.cluster_name
  kubernetes_version  = var.kubernetes_version

  # ── System Node Pool ──────────────────────────────────
  default_node_pool {
    name            = "system"
    node_count      = var.system_node_pool.node_count
    vm_size         = var.system_node_pool.vm_size
    os_disk_size_gb = var.system_node_pool.os_disk_size_gb
    vnet_subnet_id  = var.subnet_id
    zones           = ["1", "2", "3"]
    min_count       = var.system_node_pool.min_count
    max_count       = var.system_node_pool.max_count
    type            = "VirtualMachineScaleSets"

    auto_scaling_enabled = true

    node_labels = {
      "workload-type" = "system"
      "environment"   = var.environment
    }

    upgrade_settings {
      max_surge = "25%"
    }
  }

  # ── Identity ──────────────────────────────────────────
  identity {
    type = "SystemAssigned"
  }

  # ── Network Profile ───────────────────────────────────
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
    service_cidr      = "172.16.0.0/16"
    dns_service_ip    = "172.16.0.10"
  }

  # ── Azure AD RBAC ─────────────────────────────────────
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  # ── Workload Identity ─────────────────────────────────
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  # ── OMS Agent (Container Insights) ───────────────────
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  azure_policy_enabled             = true
  http_application_routing_enabled = false

  # ── Key Vault Secrets Provider ────────────────────────
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,
      kubernetes_version,
    ]
  }
}

# ── App General Node Pool ─────────────────────────────────
resource "azurerm_kubernetes_cluster_node_pool" "app_general" {
  name                  = "appgeneral"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.app_node_pool.vm_size
  node_count            = var.app_node_pool.node_count
  vnet_subnet_id        = var.subnet_id
  zones                 = ["1", "2", "3"]
  auto_scaling_enabled  = true
  min_count             = var.app_node_pool.min_count
  max_count             = var.app_node_pool.max_count
  os_disk_size_gb       = var.app_node_pool.os_disk_size_gb
  priority              = "Regular"

  node_labels = {
    "workload-type" = "general"
    "environment"   = var.environment
  }

  upgrade_settings {
    max_surge = "25%"
  }

  tags = local.common_tags
}

# ── Spot Node Pool ────────────────────────────────────────
resource "azurerm_kubernetes_cluster_node_pool" "app_spot" {
  name                  = "appspot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.spot_node_pool.vm_size
  vnet_subnet_id        = var.subnet_id
  zones                 = ["1", "2", "3"]
  auto_scaling_enabled  = true
  min_count             = 0
  max_count             = var.spot_node_pool.max_count
  os_disk_size_gb       = 100
  priority              = "Spot"
  eviction_policy       = "Delete"
  spot_max_price        = -1

  node_labels = {
    "workload-type"                         = "spot"
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }

  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]

  tags = local.common_tags
}

# ── ACR Pull Role Assignment ──────────────────────────────
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# ── Cluster Admin Role Assignments ───────────────────────
resource "azurerm_role_assignment" "aks_cluster_admin" {
  for_each = toset(var.admin_group_object_ids)

  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  principal_id         = each.value
}

# ── Diagnostic Settings ───────────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${local.cluster_name}-diagnostics"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id

  enabled_log { category = "kube-apiserver" }
  enabled_log { category = "kube-audit" }
  enabled_log { category = "kube-controller-manager" }
  enabled_log { category = "kube-scheduler" }
  enabled_log { category = "cluster-autoscaler" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
