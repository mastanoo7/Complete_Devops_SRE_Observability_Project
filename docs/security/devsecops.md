# DevSecOps — NexaCommerce

## Overview
Security is integrated at every stage of the development lifecycle — from code commit to production runtime. This document describes the DevSecOps implementation.

---

## Security Gates in CI/CD

```
Developer commits code
    ↓
Pre-commit hooks (GitLeaks, lint)
    ↓
PR opened → GitHub Actions
    ├── Secret scan (GitLeaks + TruffleHog)
    ├── SAST (CodeQL + SonarQube)
    ├── SCA (Snyk + OWASP Dependency Check)
    ├── IaC scan (Checkov + tfsec)
    └── K8s manifest scan (Kubesec)
    ↓
Build → Container image
    ├── Trivy (CVE scan)
    ├── Grype (SBOM + CVE)
    └── Cosign (image signing)
    ↓
Deploy to Staging
    └── DAST (OWASP ZAP)
    ↓
Deploy to Production
    ├── Kyverno (admission control)
    ├── OPA Gatekeeper (policy enforcement)
    ├── Falco (runtime detection)
    └── Vault (secrets injection)
```

---

## Security Tools

| Stage | Tool | Purpose | Block on Failure |
|-------|------|---------|-----------------|
| Pre-commit | GitLeaks | Secret detection | Yes |
| CI | CodeQL | SAST | Yes (Critical) |
| CI | SonarQube | Code quality + SAST | Yes (Critical) |
| CI | Snyk | SCA | Yes (Critical) |
| CI | Checkov | IaC security | Yes (High) |
| CI | tfsec | Terraform security | Yes (High) |
| Build | Trivy | Container CVE scan | Yes (Critical) |
| Build | Cosign | Image signing | Yes |
| Staging | OWASP ZAP | DAST | Yes (High) |
| Runtime | Falco | Threat detection | Alert |
| Runtime | Kyverno | Policy enforcement | Yes |
| Runtime | OPA Gatekeeper | Policy enforcement | Yes |
| Runtime | Vault | Secrets management | Yes |

---

## Pre-commit Hooks

```bash
# Install pre-commit
pip install pre-commit
pre-commit install

# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: detect-private-key
      - id: check-added-large-files
      - id: trailing-whitespace
```

---

## Vulnerability Management

### Severity Thresholds

| Severity | CI Action | SLA for Fix |
|----------|-----------|-------------|
| Critical | Block build | 24 hours |
| High | Block build | 7 days |
| Medium | Warn | 30 days |
| Low | Log | 90 days |

### False Positive Management

```bash
# Trivy: ignore specific CVE
# .trivyignore
CVE-2023-12345  # False positive: not exploitable in our context

# Snyk: ignore specific vulnerability
snyk ignore --id=SNYK-JS-LODASH-1040724 \
  --reason="Not exploitable in our usage" \
  --expiry=2024-06-01
```

---

## Compliance Scanning

```bash
# Run CIS benchmark against cluster
kube-bench run --targets master,node,etcd,policies

# Run PCI-DSS compliance check
checkov -d . --framework all \
  --check CKV_K8S_*,CKV_AWS_* \
  --compact

# Generate compliance report
bash scripts/security/compliance-report.sh \
  --standard pci-dss \
  --output reports/compliance-$(date +%Y%m%d).html
```

---

## Security Metrics

Track these in Grafana Security Dashboard:

| Metric | Target |
|--------|--------|
| Critical CVEs in production | 0 |
| Mean time to patch Critical | < 24h |
| % images with SBOM | 100% |
| % images signed | 100% |
| Falco alerts (Critical) | 0 |
| Failed Kyverno policies | 0 |

---

## Related Documents
- [IAM Strategy](iam-strategy.md)
- [Secrets Management](secrets-management.md)
- [Runtime Security](runtime-security.md)
- [Compliance](compliance.md)
- [Falco Rules](../../security/falco/falco-rules.yaml)
- [Kyverno Policies](../../security/kyverno/policies.yaml)
