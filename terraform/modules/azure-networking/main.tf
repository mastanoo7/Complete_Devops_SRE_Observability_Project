# ============================================================
# Terraform Azure Networking Module — Main
# Creates VNet, subnets, NSGs, and NAT gateway
# ============================================================

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(var.tags, {
    Module      = "azure-networking"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ── Resource Group ────────────────────────────────────────
resource "azurerm_resource_group" "network" {
  name     = "${local.name_prefix}-network-rg"
  location = var.location
  tags     = local.common_tags
}

# ── Virtual Network ───────────────────────────────────────
resource "azurerm_virtual_network" "main" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = [var.vnet_cidr]
  dns_servers         = []

  tags = local.common_tags
}

# ── Subnets ───────────────────────────────────────────────

# AKS system nodes subnet
resource "azurerm_subnet" "aks_system" {
  name                 = "${local.name_prefix}-aks-system-subnet"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_system_subnet_cidr]

  service_endpoints = [
    "Microsoft.ContainerRegistry",
    "Microsoft.KeyVault",
    "Microsoft.Storage",
  ]
}

# AKS app nodes subnet
resource "azurerm_subnet" "aks_app" {
  name                 = "${local.name_prefix}-aks-app-subnet"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_app_subnet_cidr]

  service_endpoints = [
    "Microsoft.ContainerRegistry",
    "Microsoft.KeyVault",
    "Microsoft.Storage",
    "Microsoft.Sql",
  ]
}

# Data subnet (databases, cache)
resource "azurerm_subnet" "data" {
  name                 = "${local.name_prefix}-data-subnet"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.data_subnet_cidr]

  service_endpoints = [
    "Microsoft.Sql",
    "Microsoft.Storage",
  ]

  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Application Gateway subnet
resource "azurerm_subnet" "appgw" {
  name                 = "${local.name_prefix}-appgw-subnet"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.appgw_subnet_cidr]
}

# ── Network Security Groups ───────────────────────────────

# NSG for AKS nodes
resource "azurerm_network_security_group" "aks" {
  name                = "${local.name_prefix}-aks-nsg"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# NSG for data subnet
resource "azurerm_network_security_group" "data" {
  name                = "${local.name_prefix}-data-nsg"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowPostgresFromAKS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.aks_app_subnet_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowRedisFromAKS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6380"
    source_address_prefix      = var.aks_app_subnet_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# ── NSG Associations ──────────────────────────────────────
resource "azurerm_subnet_network_security_group_association" "aks_system" {
  subnet_id                 = azurerm_subnet.aks_system.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "aks_app" {
  subnet_id                 = azurerm_subnet.aks_app.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}

# ── NAT Gateway ───────────────────────────────────────────
resource "azurerm_public_ip" "nat" {
  name                = "${local.name_prefix}-nat-pip"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.common_tags
}

resource "azurerm_nat_gateway" "main" {
  name                    = "${local.name_prefix}-nat-gw"
  location                = azurerm_resource_group.network.location
  resource_group_name     = azurerm_resource_group.network.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = ["1"]
  tags                    = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "aks_system" {
  subnet_id      = azurerm_subnet.aks_system.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

resource "azurerm_subnet_nat_gateway_association" "aks_app" {
  subnet_id      = azurerm_subnet.aks_app.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# ── Network Watcher Flow Logs ─────────────────────────────
resource "azurerm_network_watcher" "main" {
  count               = var.enable_network_watcher ? 1 : 0
  name                = "${local.name_prefix}-network-watcher"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.common_tags
}
