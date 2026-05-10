# ============================================================
# Azure Production Environment — Outputs
# ============================================================

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = module.aks.cluster_name
}

output "aks_cluster_fqdn" {
  description = "AKS cluster FQDN"
  value       = module.aks.cluster_fqdn
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity"
  value       = module.aks.oidc_issuer_url
}

output "container_registry_login_server" {
  description = "ACR login server URL"
  value       = azurerm_container_registry.main.login_server
}

output "cosmosdb_endpoint" {
  description = "CosmosDB account endpoint"
  value       = azurerm_cosmosdb_account.main.endpoint
  sensitive   = true
}

output "redis_hostname" {
  description = "Azure Cache for Redis hostname"
  value       = azurerm_redis_cache.main.hostname
  sensitive   = true
}

output "redis_ssl_port" {
  description = "Azure Cache for Redis SSL port"
  value       = azurerm_redis_cache.main.ssl_port
}

output "postgres_fqdn" {
  description = "PostgreSQL Flexible Server FQDN"
  value       = azurerm_postgresql_flexible_server.main.fqdn
  sensitive   = true
}

output "key_vault_uri" {
  description = "Azure Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.networking.vnet_id
}

output "kubeconfig_command" {
  description = "Command to configure kubectl for AKS"
  value       = "az aks get-credentials --resource-group ${module.aks.resource_group_name} --name ${module.aks.cluster_name}"
}
