# ============================================================
# GCP Production Environment — Outputs
# ============================================================

output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster API endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "gke_kubeconfig_command" {
  description = "Command to configure kubectl for GKE"
  value       = module.gke.kubeconfig_command
}

output "artifact_registry_url" {
  description = "Artifact Registry URL for container images"
  value       = "${local.region}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.containers.repository_id}"
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL instance connection name"
  value       = google_sql_database_instance.main.connection_name
}

output "cloud_sql_private_ip" {
  description = "Cloud SQL private IP address"
  value       = google_sql_database_instance.main.private_ip_address
  sensitive   = true
}

output "redis_host" {
  description = "Memorystore Redis host"
  value       = google_redis_instance.main.host
  sensitive   = true
}

output "redis_port" {
  description = "Memorystore Redis port"
  value       = google_redis_instance.main.port
}

output "workload_identity_pool" {
  description = "Workload Identity pool"
  value       = module.gke.workload_identity_pool
}

output "network_name" {
  description = "VPC network name"
  value       = module.networking.network_name
}
