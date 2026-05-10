# IAM Strategy — NexaCommerce

## Overview
NexaCommerce implements **zero-trust identity** with least-privilege access across all three clouds using cloud-native identity mechanisms.

---

## Principles

1. **Least Privilege** — every identity gets minimum permissions needed
2. **No Long-Lived Credentials** — use OIDC, IRSA, Workload Identity
3. **Separation of Duties** — different roles for dev, ops, security
4. **Just-in-Time Access** — temporary elevated access via PAM
5. **Audit Everything** — all access logged and monitored

---

## Human Identity

### Role Hierarchy

| Role | Access | MFA Required |
|------|--------|-------------|
| Developer | Read pods/logs in dev/staging | Yes |
| Senior Engineer | Deploy to dev/staging, read prod | Yes |
| Platform Engineer | Full access to platform components | Yes + Hardware key |
| SRE | Full prod access (break-glass) | Yes + Hardware key |
| Security Engineer | Read-only + security tools | Yes + Hardware key |
| Auditor | Read-only all environments | Yes |

### SSO Configuration
```yaml
Provider: Okta / Azure AD
Protocol: SAML 2.0 + OIDC
MFA: TOTP or WebAuthn (hardware key for privileged)
Session: 8 hours (re-auth for sensitive operations)
```

---

## Machine Identity (AWS — IRSA)

Each Kubernetes service account maps to a dedicated IAM role:

```hcl
# Pattern: nexacommerce-{env}-{service}-role
# Trust policy: OIDC federation from EKS

resource "aws_iam_role" "service" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = var.oidc_provider_arn }
      Condition = {
        StringEquals = {
          "${oidc_url}:sub" = "system:serviceaccount:${namespace}:${service}"
        }
      }
    }]
  })
}
```

### Service → IAM Role Mapping (Production)

| Service | IAM Role | Key Permissions |
|---------|---------|----------------|
| auth-service | `nexacommerce-prod-auth-role` | SecretsManager:GetSecretValue |
| product-service | `nexacommerce-prod-product-role` | S3:GetObject, S3:PutObject |
| order-service | `nexacommerce-prod-order-role` | SQS:SendMessage, SNS:Publish |
| payment-service | `nexacommerce-prod-payment-role` | SecretsManager, KMS:Decrypt |
| notification-service | `nexacommerce-prod-notify-role` | SES:SendEmail, SNS:Publish |

---

## Machine Identity (Azure — Workload Identity)

```yaml
# AKS Workload Identity binding
apiVersion: v1
kind: ServiceAccount
metadata:
  name: product-service
  annotations:
    azure.workload.identity/client-id: <managed-identity-client-id>
```

---

## Machine Identity (GCP — Workload Identity)

```bash
# Bind K8s SA to GCP SA
gcloud iam service-accounts add-iam-policy-binding \
  nexacommerce-product-service@PROJECT.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT.svc.id.goog[nexacommerce-prod/product-service]"
```

---

## CI/CD Identity

```yaml
# GitHub Actions uses OIDC — no static credentials
# Trust policy allows only specific repo + workflow
Condition:
  StringEquals:
    token.actions.githubusercontent.com:sub:
      "repo:your-org/nexacommerce:environment:production"
```

---

## Related Documents
- [Secrets Management](secrets-management.md)
- [Terraform IAM Module](../../terraform/modules/iam/)
- [Security Architecture](../architecture/security-architecture.md)
