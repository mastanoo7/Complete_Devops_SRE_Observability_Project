# ============================================================
# Azure Production Environment — Main Configuration
# Deploys AKS + networking + databases for Azure production
# ============================================================

locals {
  environment = "prod"
  project     = "nexacommerce"
  location    = "westeurope"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Cloud       = "azure"
    Owner       = "platform-team"
  }
}

# ── Azure Container Registry ──────────────────────────────
resource "azurerm_resource_group" "shared" {
  name     = "${local.project}-${local.environment}-shared-rg"
  location = local.location
  tags     = local.common_tags
}

resource "azurerm_container_registry" "main" {
  name                = "${local.project}${local.environment}acr"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  sku                 = "Premium"
  admin_enabled       = false

  georeplications {
    location                = "eastus2"
    zone_redundancy_enabled = true
  }

  network_rule_set {
    default_action = "Deny"
  }

  retention_policy {
    days    = 30
    enabled = true
  }

  trust_policy {
    enabled = true
  }

  tags = local.common_tags
}

# ── Networking Module ─────────────────────────────────────
module "networking" {
  source = "../../modules/azure-networking"

  project     = local.project
  environment = local.environment
  location    = local.location

  vnet_cidr              = "10.10.0.0/16"
  aks_system_subnet_cidr = "10.10.1.0/24"
  aks_app_subnet_cidr    = "10.10.2.0/22"
  data_subnet_cidr       = "10.10.10.0/24"
  appgw_subnet_cidr      = "10.10.20.0/24"
  enable_network_watcher = true

  tags = local.common_tags
}

# ── AKS Module ────────────────────────────────────────────
module "aks" {
  source = "../../modules/aks"

  project     = local.project
  environment = local.environment
  location    = local.location

  kubernetes_version    = "1.29"
  subnet_id             = module.networking.aks_app_subnet_id
  container_registry_id = azurerm_container_registry.main.id

  admin_group_object_ids = var.aks_admin_group_ids

  system_node_pool = {
    vm_size         = "Standard_D4s_v3"
    node_count      = 3
    min_count       = 3
    max_count       = 6
    os_disk_size_gb = 50
  }

  app_node_pool = {
    vm_size         = "Standard_D8s_v3"
    node_count      = 6
    min_count       = 3
    max_count       = 30
    os_disk_size_gb = 100
  }

  spot_node_pool = {
    vm_size   = "Standard_D8s_v3"
    max_count = 20
  }

  tags = local.common_tags
}

# ── Azure Key Vault ───────────────────────────────────────
resource "azurerm_key_vault" "main" {
  name                        = "${local.project}-${local.environment}-kv"
  location                    = local.location
  resource_group_name         = azurerm_resource_group.shared.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "premium"
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true
  enable_rbac_authorization   = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.allowed_ip_ranges
    virtual_network_subnet_ids = [
      module.networking.aks_app_subnet_id,
    ]
  }

  tags = local.common_tags
}

# ── CosmosDB ──────────────────────────────────────────────
resource "azurerm_cosmosdb_account" "main" {
  name                = "${local.project}-${local.environment}-cosmos"
  location            = local.location
  resource_group_name = azurerm_resource_group.shared.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  geo_location {
    location          = local.location
    failover_priority = 0
    zone_redundant    = true
  }

  geo_location {
    location          = "eastus2"
    failover_priority = 1
    zone_redundant    = false
  }

  enable_automatic_failover       = true
  is_virtual_network_filter_enabled = true

  virtual_network_rule {
    id = module.networking.aks_app_subnet_id
  }

  backup {
    type               = "Continuous"
    tier               = "Continuous30Days"
  }

  tags = local.common_tags
}

# ── Azure Cache for Redis ─────────────────────────────────
resource "azurerm_redis_cache" "main" {
  name                = "${local.project}-${local.environment}-redis"
  location            = local.location
  resource_group_name = azurerm_resource_group.shared.name
  capacity            = 3
  family              = "P"
  sku_name            = "Premium"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
    enable_authentication = true
    maxmemory_policy      = "allkeys-lru"
  }

  patch_schedule {
    day_of_week    = "Sunday"
    start_hour_utc = 2
  }

  tags = local.common_tags
}

# ── Azure PostgreSQL Flexible Server ─────────────────────
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${local.project}-${local.environment}-postgres"
  resource_group_name    = azurerm_resource_group.shared.name
  location               = local.location
  version                = "15"
  delegated_subnet_id    = module.networking.data_subnet_id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres.id
  administrator_login    = var.db_admin_username
  administrator_password = var.db_admin_password
  zone                   = "1"

  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }

  storage {
    size_gb = 512
  }

  sku_name   = "GP_Standard_D8s_v3"
  backup_retention_days        = 35
  geo_redundant_backup_enabled = true

  tags = local.common_tags
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "${local.project}-${local.environment}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.shared.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${local.project}-${local.environment}-postgres-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = module.networking.vnet_id
  resource_group_name   = azurerm_resource_group.shared.name
  tags                  = local.common_tags
}

data "azurerm_client_config" "current" {}
