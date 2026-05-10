# ============================================================
# HashiCorp Vault — Production Configuration
# HA cluster with AWS KMS auto-unseal
# ============================================================

# ── Storage Backend (Raft) ────────────────────────────────
storage "raft" {
  path    = "/vault/data"
  node_id = "vault-0"

  retry_join {
    leader_api_addr = "https://vault-0.vault-internal:8200"
  }
  retry_join {
    leader_api_addr = "https://vault-1.vault-internal:8200"
  }
  retry_join {
    leader_api_addr = "https://vault-2.vault-internal:8200"
  }

  # Performance tuning
  performance_multiplier = 1
  snapshot_threshold     = 8192
  trailing_logs          = 10240
}

# ── Listener ─────────────────────────────────────────────
listener "tcp" {
  address            = "0.0.0.0:8200"
  cluster_address    = "0.0.0.0:8201"
  tls_cert_file      = "/vault/tls/tls.crt"
  tls_key_file       = "/vault/tls/tls.key"
  tls_min_version    = "tls13"

  # Telemetry
  telemetry {
    unauthenticated_metrics_access = false
  }
}

# ── AWS KMS Auto-Unseal ───────────────────────────────────
seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "alias/nexacommerce-vault-unseal"
}

# ── Cluster Configuration ─────────────────────────────────
cluster_addr  = "https://VAULT_POD_IP:8201"
api_addr      = "https://vault.security.svc.cluster.local:8200"
cluster_name  = "nexacommerce-prod"

# ── Telemetry ─────────────────────────────────────────────
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
  statsite_address          = ""
  statsd_address            = ""
}

# ── UI ────────────────────────────────────────────────────
ui = true

# ── Logging ──────────────────────────────────────────────
log_level  = "info"
log_format = "json"

# ── Performance ──────────────────────────────────────────
default_lease_ttl = "1h"
max_lease_ttl     = "24h"
