#!/bin/bash
# ============================================================
# Vault Initialization Script
# Sets up auth methods, secret engines, and policies
# ============================================================

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-https://vault.security.svc.cluster.local:8200}"
NAMESPACE="${NAMESPACE:-nexacommerce-prod}"

echo "🔑 Initializing Vault at $VAULT_ADDR"

# ── Enable Kubernetes Auth Method ────────────────────────
echo "Enabling Kubernetes auth method..."
vault auth enable kubernetes 2>/dev/null || true

vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token \
  issuer="https://kubernetes.default.svc.cluster.local"

# ── Enable Secret Engines ─────────────────────────────────
echo "Enabling secret engines..."

# KV v2 for application secrets
vault secrets enable -path=secret kv-v2 2>/dev/null || true

# Database secrets engine
vault secrets enable database 2>/dev/null || true

# PKI for TLS certificates
vault secrets enable pki 2>/dev/null || true
vault secrets tune -max-lease-ttl=87600h pki

# AWS secrets engine
vault secrets enable aws 2>/dev/null || true

# ── Configure Database Secret Engine ─────────────────────
echo "Configuring database secret engine..."

vault write database/config/nexacommerce-postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="auth-service,product-service,order-service,payment-service,inventory-service" \
  connection_url="postgresql://{{username}}:{{password}}@aurora-writer.nexacommerce.internal:5432/nexacommerce?sslmode=require" \
  username="vault-admin" \
  password="${DB_VAULT_PASSWORD}"

# Create database roles per service
for SERVICE in auth-service product-service order-service payment-service inventory-service; do
  DB_NAME="${SERVICE//-/_}_db"
  vault write database/roles/${SERVICE} \
    db_name=nexacommerce-postgres \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT CONNECT ON DATABASE ${DB_NAME} TO \"{{name}}\"; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"
done

# ── Configure PKI ─────────────────────────────────────────
echo "Configuring PKI..."

# Generate root CA
vault write -field=certificate pki/root/generate/internal \
  common_name="NexaCommerce Root CA" \
  ttl=87600h > /tmp/root-ca.crt

# Configure PKI URLs
vault write pki/config/urls \
  issuing_certificates="${VAULT_ADDR}/v1/pki/ca" \
  crl_distribution_points="${VAULT_ADDR}/v1/pki/crl"

# Create intermediate CA
vault secrets enable -path=pki_int pki 2>/dev/null || true
vault secrets tune -max-lease-ttl=43800h pki_int

vault write -format=json pki_int/intermediate/generate/internal \
  common_name="NexaCommerce Intermediate CA" \
  | jq -r '.data.csr' > /tmp/pki_int.csr

vault write -format=json pki/root/sign-intermediate \
  csr=@/tmp/pki_int.csr \
  format=pem_bundle \
  ttl=43800h \
  | jq -r '.data.certificate' > /tmp/intermediate.cert.pem

vault write pki_int/intermediate/set-signed \
  certificate=@/tmp/intermediate.cert.pem

# Create certificate role for services
vault write pki_int/roles/nexacommerce-services \
  allowed_domains="nexacommerce-prod.svc.cluster.local,nexacommerce.internal" \
  allow_subdomains=true \
  max_ttl=720h

# ── Create Vault Policies ─────────────────────────────────
echo "Creating Vault policies..."

# Auth service policy
vault policy write auth-service - <<EOF
path "secret/data/nexacommerce/auth-service/*" {
  capabilities = ["read"]
}
path "database/creds/auth-service" {
  capabilities = ["read"]
}
path "pki_int/issue/nexacommerce-services" {
  capabilities = ["create", "update"]
}
EOF

# Product service policy
vault policy write product-service - <<EOF
path "secret/data/nexacommerce/product-service/*" {
  capabilities = ["read"]
}
path "database/creds/product-service" {
  capabilities = ["read"]
}
EOF

# Payment service policy (stricter)
vault policy write payment-service - <<EOF
path "secret/data/nexacommerce/payment-service/*" {
  capabilities = ["read"]
}
path "database/creds/payment-service" {
  capabilities = ["read"]
}
path "secret/data/nexacommerce/payment-service/stripe" {
  capabilities = ["read"]
}
EOF

# Order service policy
vault policy write order-service - <<EOF
path "secret/data/nexacommerce/order-service/*" {
  capabilities = ["read"]
}
path "database/creds/order-service" {
  capabilities = ["read"]
}
EOF

# ── Create Kubernetes Auth Roles ──────────────────────────
echo "Creating Kubernetes auth roles..."

for SERVICE in auth-service product-service order-service payment-service inventory-service notification-service; do
  vault write auth/kubernetes/role/${SERVICE} \
    bound_service_account_names=${SERVICE} \
    bound_service_account_namespaces=${NAMESPACE} \
    policies=${SERVICE} \
    ttl=1h \
    max_ttl=24h
done

# ── Store Initial Secrets ─────────────────────────────────
echo "Storing initial secrets..."

vault kv put secret/nexacommerce/auth-service \
  jwt_secret="${JWT_SECRET}" \
  google_client_id="${GOOGLE_CLIENT_ID}" \
  google_client_secret="${GOOGLE_CLIENT_SECRET}"

vault kv put secret/nexacommerce/payment-service \
  stripe_secret_key="${STRIPE_SECRET_KEY}" \
  stripe_webhook_secret="${STRIPE_WEBHOOK_SECRET}"

vault kv put secret/nexacommerce/notification-service \
  smtp_password="${SMTP_PASSWORD}" \
  sendgrid_api_key="${SENDGRID_API_KEY}"

echo "✅ Vault initialization complete!"
