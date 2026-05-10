# GitHub Actions — NexaCommerce CI/CD

## Overview
NexaCommerce uses GitHub Actions for all CI/CD workflows. Pipelines are split by concern and environment.

---

## Workflow Inventory

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| Backend CI | `backend-ci.yml` | Push/PR to backend/ | Build, test, push images |
| Frontend CI | `frontend-ci.yml` | Push/PR to frontend/ | Build, test, E2E, Lighthouse |
| Security Scan | `security-scan.yml` | Push/PR + nightly | SAST, SCA, container scan, SBOM |
| Terraform CI | `terraform-ci.yml` | Push/PR to terraform/ | Validate, plan, apply |
| Deploy DEV | `deployment-dev.yml` | Push to main | Auto-deploy to DEV |
| Deploy Staging | `deployment-staging.yml` | Release tags | Deploy + E2E + DAST |
| Deploy Prod | `deployment-prod.yml` | Manual trigger | Canary deploy to production |

---

## Secrets Configuration

Configure these secrets in GitHub → Settings → Secrets:

| Secret | Description |
|--------|-------------|
| `AWS_CI_ROLE_ARN` | IAM role ARN for CI/CD (OIDC) |
| `ECR_REGISTRY` | ECR registry URL |
| `ARGOCD_SERVER` | ArgoCD server URL |
| `ARGOCD_TOKEN` | ArgoCD API token |
| `GITOPS_TOKEN` | GitHub token for manifest updates |
| `SLACK_WEBHOOK_DEPLOYMENTS` | Slack webhook for deploy notifications |
| `SLACK_WEBHOOK_DEV` | Slack webhook for dev notifications |
| `SNYK_TOKEN` | Snyk API token for SCA |
| `SONAR_TOKEN` | SonarQube token for SAST |
| `NEXT_PUBLIC_API_URL` | Frontend API URL |

---

## OIDC Authentication (No Long-Lived Secrets)

GitHub Actions uses OIDC to authenticate with AWS — no static credentials:

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - name: Configure AWS credentials
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ secrets.AWS_CI_ROLE_ARN }}
      aws-region: us-east-1
```

IAM Trust Policy:
```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": "repo:your-org/nexacommerce:*"
    }
  }
}
```

---

## Branch Protection Rules

Configure in GitHub → Settings → Branches → main:

```yaml
Required status checks:
  - backend-ci / lint
  - backend-ci / unit-tests
  - backend-ci / build
  - security-scan / secret-scan
  - security-scan / sast (go)
  - security-scan / sast (java)

Required reviews: 2
Dismiss stale reviews: true
Require review from code owners: true
Restrict pushes: true (only via PR)
```

---

## Workflow Optimization

### Build Caching
```yaml
# Docker layer caching
- uses: docker/setup-buildx-action@v3
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### Matrix Builds
```yaml
# Build all services in parallel
strategy:
  matrix:
    service: [auth-service, product-service, order-service]
  fail-fast: false
```

### Conditional Execution
```yaml
# Only run if relevant files changed
on:
  push:
    paths:
      - "backend/**"
      - ".github/workflows/backend-ci.yml"
```

---

## Monitoring CI/CD

- **GitHub Actions dashboard**: Monitor workflow runs
- **Slack #ci-builds**: Build notifications
- **Grafana**: CI/CD metrics (build time, success rate)
- **PagerDuty**: Alert on repeated failures

---

## Related Files
- [Backend CI](../../.github/workflows/backend-ci.yml)
- [Frontend CI](../../.github/workflows/frontend-ci.yml)
- [Security Scan](../../.github/workflows/security-scan.yml)
- [Terraform CI](../../.github/workflows/terraform-ci.yml)
- [Deploy DEV](../../.github/workflows/deployment-dev.yml)
- [Deploy Staging](../../.github/workflows/deployment-staging.yml)
- [Deploy Prod](../../.github/workflows/deployment-prod.yml)
