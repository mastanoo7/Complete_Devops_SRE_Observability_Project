# Compliance — NexaCommerce

## Overview
NexaCommerce maintains compliance with PCI-DSS Level 1, SOC 2 Type II, GDPR, and CCPA.

---

## PCI-DSS Level 1

### Scope
Payment service and all systems that store, process, or transmit cardholder data.

### Key Controls

| Requirement | Implementation |
|-------------|---------------|
| 1. Network security | VPC isolation, security groups, network policies |
| 2. No vendor defaults | All default passwords changed, unnecessary services disabled |
| 3. Protect stored data | No card data stored (tokenized via Stripe) |
| 4. Encrypt transmission | TLS 1.3 + mTLS for all payment traffic |
| 5. Anti-malware | Falco runtime detection, container scanning |
| 6. Secure systems | Trivy CVE scanning, patch management |
| 7. Restrict access | RBAC, least privilege, IRSA |
| 8. Identify users | SSO + MFA, no shared accounts |
| 9. Physical security | Cloud provider responsibility (AWS/Azure/GCP) |
| 10. Monitor access | CloudTrail, K8s audit logs, Vault audit |
| 11. Test security | Quarterly pen testing, annual PCI audit |
| 12. Security policy | This document + security architecture |

### Payment Service Isolation
```yaml
# Payment service runs on dedicated PCI-scoped nodes
nodeSelector:
  workload-type: payment-pci
tolerations:
  - key: payment-pci
    effect: NoSchedule

# Strict network policy — only order-service can call payment-service
# Only payment-service can reach Stripe API
```

---

## SOC 2 Type II

### Trust Service Criteria

| Criteria | Controls |
|----------|---------|
| Security | Falco, Kyverno, WAF, mTLS, Vault |
| Availability | Multi-cloud active-active, 99.9% SLO |
| Processing Integrity | Order/payment audit logs, idempotency |
| Confidentiality | Encryption at rest/transit, RBAC |
| Privacy | GDPR controls, data minimization |

### Evidence Collection
```bash
# Generate SOC 2 evidence report
bash scripts/compliance/generate-soc2-evidence.sh \
  --period "2024-01-01:2024-12-31" \
  --output reports/soc2-evidence-2024.pdf
```

---

## GDPR Compliance

### Data Subject Rights

| Right | Implementation |
|-------|---------------|
| Access | User data export API: `GET /api/v1/users/me/data` |
| Rectification | Profile update API |
| Erasure | Account deletion: `DELETE /api/v1/users/me` |
| Portability | JSON export of all user data |
| Restriction | Account suspension without deletion |
| Objection | Marketing opt-out |

### Data Retention

| Data Type | Retention | Basis |
|-----------|-----------|-------|
| Order history | 7 years | Legal (tax) |
| Payment records | 7 years | Legal (PCI) |
| User profiles | Until deletion request | Consent |
| Logs | 1 year | Legitimate interest |
| Analytics | 2 years | Legitimate interest |

### Data Processing Records
```bash
# View data processing activities
cat docs/compliance/data-processing-activities.md

# Generate GDPR compliance report
bash scripts/compliance/gdpr-report.sh
```

---

## CCPA Compliance

### Consumer Rights
- Right to Know: Privacy policy + data export
- Right to Delete: Account deletion API
- Right to Opt-Out: Marketing preferences
- Right to Non-Discrimination: Same service regardless of privacy choices

---

## Compliance Scanning

```bash
# Run CIS Kubernetes Benchmark
kube-bench run --targets master,node,etcd,policies \
  --json > reports/cis-benchmark-$(date +%Y%m%d).json

# Run PCI-DSS compliance check
checkov -d . --framework all \
  --check CKV_K8S_*,CKV_AWS_* \
  --output json > reports/pci-compliance-$(date +%Y%m%d).json

# AWS Security Hub compliance
aws securityhub get-findings \
  --filters '{"ComplianceStatus":[{"Value":"FAILED","Comparison":"EQUALS"}]}' \
  --query 'Findings[*].{Title:Title,Severity:Severity.Label}'
```

---

## Audit Schedule

| Audit | Frequency | Owner |
|-------|-----------|-------|
| PCI-DSS QSA | Annual | Security team |
| SOC 2 | Annual | Security team |
| Penetration test | Quarterly | External vendor |
| Vulnerability scan | Weekly (automated) | Platform team |
| Access review | Quarterly | Security team |
| DR drill | Quarterly | SRE team |

---

## Related Documents
- [Security Architecture](../architecture/security-architecture.md)
- [IAM Strategy](iam-strategy.md)
- [DevSecOps](devsecops.md)
- [Runtime Security](runtime-security.md)
