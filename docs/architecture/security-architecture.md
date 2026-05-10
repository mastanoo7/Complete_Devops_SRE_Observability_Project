# Security Architecture — NexaCommerce

## Overview
NexaCommerce implements **defense-in-depth** security across all layers: edge, network, application, container, and data. The platform is designed to meet **PCI-DSS Level 1**, **SOC 2 Type II**, and **ISO 27001** compliance requirements.

---

## Security Layers

```
Layer 1: Edge Security       — CloudFlare WAF, DDoS, Bot protection
Layer 2: Network Security    — VPC isolation, Security Groups, NACLs
Layer 3: Identity & Access   — Zero-trust IAM, OIDC, IRSA, Workload Identity
Layer 4: API Security        — Kong rate limiting, JWT validation, mTLS
Layer 5: Container Security  — Image scanning, Kyverno policies, OPA
Layer 6: Runtime Security    — Falco threat detection, eBPF monitoring
Layer 7: Data Security       — Encryption at rest/transit, Vault secrets
Layer 8: Observability       — Audit logs, SIEM, anomaly detection
```

---

## Identity & Access Management

### Zero-Trust Principles
- **Never trust, always verify** — every request authenticated
- **Least privilege** — minimum permissions per service
- **Assume breach** — monitor all internal traffic

### Human Identity (Employees)
```
SSO Provider: Okta / Azure AD
MFA: Required for all users
Session: 8-hour max, re-auth for sensitive ops
Privileged Access: PAM via CyberArk, just-in-time
```

### Machine Identity (Services)
| Cloud | Mechanism | Scope |
|-------|-----------|-------|
| AWS | IRSA (IAM Roles for Service Accounts) | Per K8s service account |
| Azure | Workload Identity (AAD) | Per K8s service account |
| GCP | Workload Identity Federation | Per K8s service account |

### RBAC Strategy

```yaml
# Kubernetes RBAC — least privilege
Cluster Admin:  SRE team only (break-glass)
Namespace Admin: Service owners (own namespace)
Developer:      Read pods/logs, exec into pods (dev only)
CI/CD:          Deploy to specific namespace only
Read-only:      Auditors, security team
```

---

## Secrets Management — HashiCorp Vault

### Architecture
```
Vault Cluster: 3-node HA (Raft consensus)
Backend:       AWS KMS (auto-unseal)
Auth Methods:  Kubernetes, AWS IAM, OIDC
Secret Engines: KV v2, PKI, Database, AWS
```

### Secret Injection Pattern
```yaml
# Vault Agent Sidecar Injector
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "product-service"
  vault.hashicorp.com/agent-inject-secret-db: "secret/data/product-service/db"
  vault.hashicorp.com/agent-inject-template-db: |
    {{- with secret "secret/data/product-service/db" -}}
    DATABASE_URL={{ .Data.data.url }}
    {{- end }}
```

### Secret Rotation
| Secret Type | Rotation Frequency | Method |
|-------------|-------------------|--------|
| DB passwords | 30 days | Vault Dynamic Secrets |
| API keys | 90 days | Vault KV + auto-rotation |
| TLS certificates | 90 days | Vault PKI engine |
| JWT signing keys | 180 days | Manual + Vault KV |

---

## Container Security

### Image Security Pipeline
```
1. Build:    Multi-stage Dockerfile (distroless base)
2. Scan:     Trivy (CVE scan) + Grype (SBOM)
3. Sign:     Cosign (keyless signing via Sigstore)
4. Verify:   Kyverno policy — only signed images allowed
5. Runtime:  Falco — detect anomalous container behavior
```

### Kyverno Policies (Enforced)
```yaml
# Key policies enforced in production
- require-image-signature        # Only Cosign-signed images
- disallow-latest-tag            # No :latest tag in prod
- require-resource-limits        # CPU/memory limits required
- disallow-privileged-containers # No privileged pods
- require-non-root-user          # runAsNonRoot: true
- disallow-host-namespaces       # No hostPID/hostNetwork
- require-readonly-rootfs        # readOnlyRootFilesystem: true
- require-pod-probes             # liveness + readiness required
```

### OPA Gatekeeper Constraints
```yaml
# Additional policy enforcement
- K8sRequiredLabels              # app, version, team labels required
- K8sAllowedRepos                # Only approved registries
- K8sContainerLimits             # Max CPU: 4, Max Memory: 8Gi
- K8sBlockNodePort               # No NodePort services in prod
- K8sRequireNetworkPolicy        # NetworkPolicy required per namespace
```

---

## Network Security

### mTLS with Istio
All service-to-service communication uses **mutual TLS**:
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: nexacommerce-prod
spec:
  mtls:
    mode: STRICT   # Reject all non-mTLS traffic
```

### Istio Authorization Policies
```yaml
# Example: Only order-service can call payment-service
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: payment-service-policy
spec:
  selector:
    matchLabels:
      app: payment-service
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/nexacommerce-prod/sa/order-service"
```

---

## Runtime Security — Falco

### Key Detection Rules
```yaml
# Custom Falco rules for NexaCommerce
- rule: Unexpected outbound connection from payment service
  condition: >
    outbound and container.name = "payment-service"
    and not fd.sip in (allowed_payment_ips)
  output: "Unexpected connection from payment service"
  priority: CRITICAL

- rule: Sensitive file access in container
  condition: >
    open_read and container
    and fd.name startswith /etc/shadow
  priority: WARNING

- rule: Shell spawned in container
  condition: >
    spawned_process and container
    and proc.name in (shell_binaries)
    and not proc.pname in (allowed_parents)
  priority: ERROR
```

---

## Data Security

### Encryption at Rest
| Data Store | Encryption | Key Management |
|-----------|-----------|----------------|
| Aurora PostgreSQL | AES-256 | AWS KMS CMK |
| ElastiCache Redis | AES-256 | AWS KMS CMK |
| S3 Buckets | SSE-KMS | AWS KMS CMK |
| EBS Volumes | AES-256 | AWS KMS CMK |
| CosmosDB | AES-256 | Azure Key Vault |
| Cloud Spanner | AES-256 | Google KMS |

### Encryption in Transit
- All external traffic: TLS 1.3 minimum
- All internal traffic: mTLS via Istio
- Database connections: TLS required
- Kafka: TLS + SASL_SSL

### PCI-DSS Compliance (Payment Data)
```
- Payment service runs in dedicated node group (tainted)
- No card data stored (tokenized via Stripe)
- Network isolation: payment-service ↔ Stripe only
- All payment logs redacted of card data
- Quarterly penetration testing
- Annual PCI-DSS audit
```

---

## Security Scanning in CI/CD

```yaml
# Security gates in pipeline (all must pass)
1. GitLeaks:     No secrets in code
2. SAST:         SonarQube + CodeQL (no HIGH/CRITICAL)
3. SCA:          Snyk (no CRITICAL vulnerabilities)
4. Container:    Trivy (no CRITICAL CVEs in image)
5. IaC:          Checkov (no HIGH findings in Terraform)
6. K8s:          Kubesec score > 4
7. DAST:         OWASP ZAP (staging only, no HIGH findings)
```

---

## Compliance & Audit

| Standard | Status | Scope |
|----------|--------|-------|
| PCI-DSS Level 1 | Compliant | Payment processing |
| SOC 2 Type II | Compliant | All production systems |
| ISO 27001 | In progress | Information security |
| GDPR | Compliant | EU customer data |
| CCPA | Compliant | California customer data |

### Audit Logging
- All K8s API calls: CloudTrail + K8s audit log
- All DB queries: pgaudit (PostgreSQL)
- All secret access: Vault audit log
- All auth events: Auth service audit log
- Retention: 1 year hot, 7 years cold (S3 Glacier)

---

## Related Documents

- [DevSecOps Guide](../security/devsecops.md)
- [IAM Strategy](../security/iam-strategy.md)
- [Secrets Management](../security/secrets-management.md)
- [Runtime Security](../security/runtime-security.md)
- [Compliance](../security/compliance.md)
