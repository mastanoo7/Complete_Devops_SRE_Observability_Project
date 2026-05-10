# ============================================================
# Terraform GKE Module — Main
# Creates Google Kubernetes Engine cluster with node pools
# ============================================================

locals {
  cluster_name = "${var.project}-${var.environment}"

  common_labels = merge(var.labels, {
    module      = "gke"
    environment = var.environment
    managed_by  = "terraform"
    project     = var.project
  })
}

# ── GKE Cluster ───────────────────────────────────────────
resource "google_container_cluster" "main" {
  name     = local.cluster_name
  location = var.region
  project  = var.project_id

  # Remove default node pool — use separately managed pools
  remove_default_node_pool = true
  initial_node_count       = 1

  # ── Networking ────────────────────────────────────────
  network    = var.network
  subnetwork = var.subnetwork

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # ── Private Cluster ───────────────────────────────────
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # ── Kubernetes Version ────────────────────────────────
  min_master_version = var.kubernetes_version

  release_channel {
    channel = "REGULAR"
  }

  # ── Workload Identity ─────────────────────────────────
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # ── Security ──────────────────────────────────────────
  enable_shielded_nodes = true

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # ── Add-ons ───────────────────────────────────────────
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  # ── Network Policy ────────────────────────────────────
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # ── Logging & Monitoring ──────────────────────────────
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER",
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER",
    ]
    managed_prometheus {
      enabled = true
    }
  }

  # ── Maintenance Window ────────────────────────────────
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T02:00:00Z"
      end_time   = "2024-01-01T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
  }

  # ── Resource Labels ───────────────────────────────────
  resource_labels = local.common_labels

  lifecycle {
    ignore_changes = [
      initial_node_count,
      min_master_version,
    ]
  }
}

# ── System Node Pool ──────────────────────────────────────
resource "google_container_node_pool" "system" {
  name     = "system"
  location = var.region
  cluster  = google_container_cluster.main.name
  project  = var.project_id

  initial_node_count = var.system_node_pool.initial_node_count

  autoscaling {
    min_node_count = var.system_node_pool.min_node_count
    max_node_count = var.system_node_pool.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type = var.system_node_pool.machine_type
    disk_size_gb = var.system_node_pool.disk_size_gb
    disk_type    = "pd-ssd"
    image_type   = "COS_CONTAINERD"

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Shielded nodes
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = merge(local.common_labels, {
      "workload-type" = "system"
    })

    taint {
      key    = "CriticalAddonsOnly"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
}

# ── App General Node Pool ─────────────────────────────────
resource "google_container_node_pool" "app_general" {
  name     = "app-general"
  location = var.region
  cluster  = google_container_cluster.main.name
  project  = var.project_id

  initial_node_count = var.app_node_pool.initial_node_count

  autoscaling {
    min_node_count = var.app_node_pool.min_node_count
    max_node_count = var.app_node_pool.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 2
    max_unavailable = 0
  }

  node_config {
    machine_type = var.app_node_pool.machine_type
    disk_size_gb = var.app_node_pool.disk_size_gb
    disk_type    = "pd-ssd"
    image_type   = "COS_CONTAINERD"

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = merge(local.common_labels, {
      "workload-type" = "general"
    })
  }
}

# ── Spot Node Pool ────────────────────────────────────────
resource "google_container_node_pool" "app_spot" {
  name     = "app-spot"
  location = var.region
  cluster  = google_container_cluster.main.name
  project  = var.project_id

  autoscaling {
    min_node_count = 0
    max_node_count = var.spot_node_pool.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.spot_node_pool.machine_type
    disk_size_gb = 100
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"
    spot         = true

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = merge(local.common_labels, {
      "workload-type" = "spot"
    })

    taint {
      key    = "cloud.google.com/gke-spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
}
