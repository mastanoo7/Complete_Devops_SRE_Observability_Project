# ============================================================
# Terraform GCP Networking Module — Main
# Creates VPC, subnets with secondary ranges for GKE
# ============================================================

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_labels = merge(var.labels, {
    module      = "gcp-networking"
    environment = var.environment
    managed_by  = "terraform"
  })
}

# ── VPC Network ───────────────────────────────────────────
resource "google_compute_network" "main" {
  name                    = "${local.name_prefix}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  description             = "VPC for ${local.name_prefix}"
}

# ── Primary Subnet (GKE nodes) ───────────────────────────
resource "google_compute_subnetwork" "gke" {
  name          = "${local.name_prefix}-gke-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.main.id
  ip_cidr_range = var.gke_subnet_cidr

  # Secondary ranges for GKE pods and services
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ── Data Subnet (Cloud SQL, Memorystore) ──────────────────
resource "google_compute_subnetwork" "data" {
  name          = "${local.name_prefix}-data-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.main.id
  ip_cidr_range = var.data_subnet_cidr

  private_ip_google_access = true
}

# ── Cloud Router (for Cloud NAT) ──────────────────────────
resource "google_compute_router" "main" {
  name    = "${local.name_prefix}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.main.id

  bgp {
    asn = 64514
  }
}

# ── Cloud NAT ─────────────────────────────────────────────
resource "google_compute_router_nat" "main" {
  name                               = "${local.name_prefix}-nat"
  project                            = var.project_id
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  subnetwork {
    name                    = google_compute_subnetwork.data.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ── Firewall Rules ────────────────────────────────────────

# Allow internal communication within VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "${local.name_prefix}-allow-internal"
  project = var.project_id
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.gke_subnet_cidr, var.data_subnet_cidr]
  description   = "Allow internal VPC traffic"
}

# Allow health checks from Google LB
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${local.name_prefix}-allow-health-checks"
  project = var.project_id
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "8443"]
  }

  source_ranges = [
    "35.191.0.0/16",   # Google health check ranges
    "130.211.0.0/22",
  ]
  description = "Allow Google Cloud health checks"
}

# Allow GKE master to nodes communication
resource "google_compute_firewall" "allow_master_to_nodes" {
  name    = "${local.name_prefix}-allow-master-nodes"
  project = var.project_id
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = ["443", "10250", "10255"]
  }

  source_ranges = [var.master_ipv4_cidr_block]
  description   = "Allow GKE master to node communication"
}

# Deny all other ingress
resource "google_compute_firewall" "deny_all_ingress" {
  name     = "${local.name_prefix}-deny-all-ingress"
  project  = var.project_id
  network  = google_compute_network.main.id
  priority = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  description   = "Deny all other ingress traffic"
}

# ── Private Service Access (Cloud SQL, Memorystore) ───────
resource "google_compute_global_address" "private_service_range" {
  name          = "${local.name_prefix}-private-service-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
}
