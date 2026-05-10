# ============================================================
# GCP Production Environment — Main Configuration
# Deploys GKE + networking + databases for GCP production
# ============================================================

locals {
  environment = "prod"
  project     = "nexacommerce"
  project_id  = var.gcp_project_id
  region      = "us-central1"

  common_labels = {
    project     = local.project
    environment = local.environment
    managed_by  = "terraform"
    cloud       = "gcp"
    owner       = "platform-team"
  }
}

# ── GCP Networking Module ─────────────────────────────────
module "networking" {
  source = "../../modules/gcp-networking"

  project     = local.project
  project_id  = local.project_id
  environment = local.environment
  region      = local.region

  gke_subnet_cidr        = "10.20.0.0/20"
  pods_cidr              = "10.21.0.0/16"
  services_cidr          = "10.22.0.0/20"
  data_subnet_cidr       = "10.20.16.0/24"
  master_ipv4_cidr_block = "172.16.0.0/28"

  labels = local.common_labels
}

# ── GKE Module ────────────────────────────────────────────
module "gke" {
  source = "../../modules/gke"

  project     = local.project
  project_id  = local.project_id
  environment = local.environment
  region      = local.region

  kubernetes_version = "1.29"
  network            = module.networking.network_name
  subnetwork         = module.networking.gke_subnet_name
  pods_range_name    = module.networking.pods_range_name
  services_range_name = module.networking.services_range_name

  master_ipv4_cidr_block = "172.16.0.0/28"
  master_authorized_networks = [
    {
      cidr_block   = var.vpn_cidr
      display_name = "Corporate VPN"
    }
  ]

  system_node_pool = {
    machine_type       = "e2-standard-4"
    disk_size_gb       = 50
    initial_node_count = 1
    min_node_count     = 1
    max_node_count     = 3
  }

  app_node_pool = {
    machine_type       = "n2-standard-8"
    disk_size_gb       = 100
    initial_node_count = 3
    min_node_count     = 3
    max_node_count     = 30
  }

  spot_node_pool = {
    machine_type   = "n2-standard-8"
    max_node_count = 20
  }

  labels = local.common_labels
}

# ── Artifact Registry ─────────────────────────────────────
resource "google_artifact_registry_repository" "containers" {
  location      = local.region
  project       = local.project_id
  repository_id = "${local.project}-containers"
  description   = "Container images for NexaCommerce"
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-tagged-releases"
    action = "KEEP"
    condition {
      tag_state    = "TAGGED"
      tag_prefixes = ["v", "sha-"]
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s"  # 7 days
    }
  }

  labels = local.common_labels
}

# ── Cloud SQL PostgreSQL ──────────────────────────────────
resource "google_sql_database_instance" "main" {
  name             = "${local.project}-${local.environment}-postgres"
  project          = local.project_id
  database_version = "POSTGRES_15"
  region           = local.region

  settings {
    tier              = "db-custom-8-32768"
    availability_type = "REGIONAL"
    disk_size         = 100
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 35
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = module.networking.network_id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }
    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }

    maintenance_window {
      day          = 7
      hour         = 2
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false
    }
  }

  deletion_protection = true

  depends_on = [module.networking]
}

# ── Cloud SQL Read Replica ────────────────────────────────
resource "google_sql_database_instance" "replica" {
  name                 = "${local.project}-${local.environment}-postgres-replica"
  project              = local.project_id
  database_version     = "POSTGRES_15"
  region               = "us-east1"
  master_instance_name = google_sql_database_instance.main.name

  replica_configuration {
    failover_target = false
  }

  settings {
    tier              = "db-custom-4-16384"
    availability_type = "ZONAL"
    disk_size         = 100
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = module.networking.network_id
      ssl_mode        = "ENCRYPTED_ONLY"
    }
  }

  deletion_protection = true
}

# ── Memorystore Redis ─────────────────────────────────────
resource "google_redis_instance" "main" {
  name           = "${local.project}-${local.environment}-redis"
  project        = local.project_id
  region         = local.region
  tier           = "STANDARD_HA"
  memory_size_gb = 16
  redis_version  = "REDIS_7_0"

  authorized_network = module.networking.network_id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  auth_enabled            = true
  transit_encryption_mode = "SERVER_AUTHENTICATION"

  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 2
        minutes = 0
        seconds = 0
        nanos   = 0
      }
    }
  }

  labels = local.common_labels

  depends_on = [module.networking]
}

# ── Secret Manager ────────────────────────────────────────
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${local.project}-${local.environment}-db-password"
  project   = local.project_id

  replication {
    auto {}
  }

  labels = local.common_labels
}

# ── Workload Identity Service Accounts ───────────────────
resource "google_service_account" "services" {
  for_each = toset([
    "auth-service",
    "product-service",
    "order-service",
    "payment-service",
    "notification-service",
  ])

  account_id   = "${local.project}-${each.key}"
  display_name = "NexaCommerce ${each.key}"
  project      = local.project_id
}

# Bind K8s service accounts to GCP service accounts (Workload Identity)
resource "google_service_account_iam_binding" "workload_identity" {
  for_each = google_service_account.services

  service_account_id = each.value.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${local.project_id}.svc.id.goog[nexacommerce-prod/${each.key}]",
  ]
}
