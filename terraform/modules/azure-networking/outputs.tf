# ============================================================
# Azure Networking Module — Outputs
# ============================================================

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.main.name
}

output "aks_system_subnet_id" {
  description = "AKS system node pool subnet ID"
  value       = azurerm_subnet.aks_system.id
}

output "aks_app_subnet_id" {
  description = "AKS app node pool subnet ID"
  value       = azurerm_subnet.aks_app.id
}

output "data_subnet_id" {
  description = "Data subnet ID (databases, cache)"
  value       = azurerm_subnet.data.id
}

output "appgw_subnet_id" {
  description = "Application Gateway subnet ID"
  value       = azurerm_subnet.appgw.id
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway public IP address"
  value       = azurerm_public_ip.nat.ip_address
}

output "resource_group_name" {
  description = "Network resource group name"
  value       = azurerm_resource_group.network.name
}

output "location" {
  description = "Azure region"
  value       = azurerm_resource_group.network.location
}
