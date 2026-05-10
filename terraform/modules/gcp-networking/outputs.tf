# ============================================================
# GCP Networking Module — Outputs
# ============================================================

output "network_id" {
  description = "VPC network ID"
  value       = google_compute_network.main.id
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.main.name
}

output "network_self_link" {
  description = "VPC network self_link"
  value       = google_compute_network.main.self_link
}

output "gke_subnet_id" {
  description = "GKE node subnet ID"
  value       = google_compute_subnetwork.gke.id
}

output "gke_subnet_name" {
  description = "GKE node subnet name"
  value       = google_compute_subnetwork.gke.name
}

output "gke_subnet_self_link" {
  description = "GKE node subnet self_link"
  value       = google_compute_subnetwork.gke.self_link
}

output "data_subnet_id" {
  description = "Data subnet ID"
  value       = google_compute_subnetwork.data.id
}

output "pods_range_name" {
  description = "Secondary IP range name for pods"
  value       = "pods"
}

output "services_range_name" {
  description = "Secondary IP range name for services"
  value       = "services"
}

output "router_name" {
  description = "Cloud Router name"
  value       = google_compute_router.main.name
}

output "nat_name" {
  description = "Cloud NAT name"
  value       = google_compute_router_nat.main.name
}
