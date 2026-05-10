# Secrets Management — NexaCommerce

## Overview
All secrets are managed through **HashiCorp Vault** with zero static credentials in code, environment variables, or Kubernetes secrets (except Vault-injected ones).

---

## Secret Categories

| Category | Storage | Rotation | Access |
|----------|---------|----------|--------|
| DB passwords | Vault Dynamic Secrets | Auto (1h TTL) | Per-service IRSA |
| API keys (Stripe, etc.) | Vault KV v2 | Manual (90d) | Per-service policy |
| JWT signing keys | Vault KV v2 | Manual (180d) | Auth service only |
| TLS certificates | Vault PKI | Auto (90d) | cert-manager |
| OAuth client secrets | Vault KV v2 | Manual (90d) | Auth service only |
| Infrastructure secrets | AWS Secrets Manager | Auto (30d) | Terraform |

---

## Vault Architecture

```
Vault Cluster (3-node HA, Raft consensus)
    ├── Auth Methods
    │   ├── Kubernetes (pod-level auth)
    │   ├── AWS IAM (Terraform, CI/CD)
    │   └── OIDC (human access via SSO)
    ├── Secret Engines
    │   ├── KV v2 (static secrets)
    │   ├── Database (dynamic DB credentials)
    │   ├── PKI (TLS certificates)
    │   └── AWS (dynamic IAM credentials)
    └── Policies (least-privilege per service)
```

---

## Secret Injection Pattern

### Vault Agent Sidecar (Kubernetes)

```yaml
# Pod annotation triggers Vault Agent injection
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "product-service"
  vault.hashicorp.com/agent-inject-secret-db: "database/creds/product-service"
  vault.hashicorp.com/agent-inject-template-db: |
    {{- with secret "database/creds/product-service" -}}
    SPRING_DATASOURCE_URL=jdbc:postgresql://aurora:5432/product_db
    SPRING_DATASOURCE_USERNAME={{ .Data.username }}
    SPRING_DATASOURCE_PASSWORD={{ .Data.password }}
    {{- end }}
```

### External Secrets Operator (Alternative)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: product-service-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: product-service-secrets
  data:
    - secretKey: stripe-api-key
      remoteRef:
        key: secret/nexacommerce/payment-service
        property: stripe_secret_key
```

---

## Secret Rotation

### Automatic Rotation (Database)

```bash
# Vault Dynamic Secrets — credentials auto-expire
# Product service gets new DB credentials every 1 hour
# Old credentials revoked automatically

# Verify dynamic secret
vault read database/creds/product-service
# Key                Value
# lease_id           database/creds/product-service/abc123
# lease_duration     1h
# username           v-k8s-product-abc123
# password           A1B2C3D4...
```

### Manual Rotation (API Keys)

```bash
# Rotate Stripe API key
vault kv put secret/nexacommerce/payment-service \
  stripe_secret_key="sk_live_new_key_here"

# Trigger pod restart to pick up new secret
kubectl rollout restart deployment/payment-service -n nexacommerce-prod
```

---

## Emergency Secret Revocation

```bash
# Revoke all leases for a service (breach response)
vault lease revoke -prefix database/creds/product-service

# Revoke specific token
vault token revoke <token-id>

# Seal Vault (emergency)
vault operator seal
```

---

## Audit Logging

All secret access is logged:
```bash
# View Vault audit log
vault audit list
# Path          Type    Description
# file/         file    /vault/logs/audit.log

# Query audit log for specific secret
grep "product-service" /vault/logs/audit.log | jq .
```

---

## Related Documents
- [Vault Config](../../security/vault/vault-config.hcl)
- [Vault Init Script](../../security/vault/vault-init.sh)
- [IAM Strategy](iam-strategy.md)
