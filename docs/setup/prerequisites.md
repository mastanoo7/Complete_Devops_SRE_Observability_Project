# Prerequisites — NexaCommerce Platform

## Overview
This document lists all tools required to work with the NexaCommerce platform across all roles: developer, DevOps, SRE, and security engineer.

---

## Required Accounts

| Account | Purpose | Free Tier |
|---------|---------|-----------|
| [AWS Account](https://aws.amazon.com) | Primary cloud | Yes (limited) |
| [Azure Account](https://azure.microsoft.com) | Secondary cloud | $200 credit |
| [GCP Account](https://cloud.google.com) | Tertiary cloud | $300 credit |
| [GitHub Account](https://github.com) | Source control + CI/CD | Yes |
| [Docker Hub](https://hub.docker.com) | Public image pulls | Yes |
| [CloudFlare](https://cloudflare.com) | DNS + CDN + WAF | Yes |

---

## Required Tools by Role

### 👨‍💻 All Engineers (Minimum)

| Tool | Version | Install |
|------|---------|---------|
| Git | 2.40+ | [git-scm.com](https://git-scm.com) |
| Docker Desktop | 24.0+ | [docker.com](https://docker.com) |
| kubectl | 1.29+ | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| Helm | 3.14+ | [helm.sh](https://helm.sh) |
| VS Code | Latest | [code.visualstudio.com](https://code.visualstudio.com) |
| Node.js | 20 LTS | [nodejs.org](https://nodejs.org) |
| Python | 3.11+ | [python.org](https://python.org) |
| Java (JDK) | 17 LTS | [adoptium.net](https://adoptium.net/) |
| Maven | 3.9+ | [maven.apache.org](https://maven.apache.org/) |
| Go | 1.22+ | [go.dev](https://go.dev/) |

### 🏗️ DevOps / Platform Engineers

| Tool | Version | Install |
|------|---------|---------|
| Terraform | 1.7+ | [terraform.io](https://terraform.io) |
| AWS CLI | 2.x | [aws.amazon.com/cli](https://aws.amazon.com/cli) |
| Azure CLI | 2.57+ | [learn.microsoft.com](https://learn.microsoft.com/cli/azure) |
| gcloud CLI | 460+ | [cloud.google.com/sdk](https://cloud.google.com/sdk) |
| ArgoCD CLI | 2.10+ | [argo-cd.readthedocs.io](https://argo-cd.readthedocs.io) |
| Kustomize | 5.3+ | [kustomize.io](https://kustomize.io) |
| k9s | Latest | [k9scli.io](https://k9scli.io) |
| Minikube | 1.32+ | [minikube.sigs.k8s.io](https://minikube.sigs.k8s.io) |
| Kind | 0.22+ | [kind.sigs.k8s.io](https://kind.sigs.k8s.io) |

### 🔒 Security Engineers

| Tool | Version | Install |
|------|---------|---------|
| Trivy | 0.49+ | [trivy.dev](https://trivy.dev) |
| GitLeaks | 8.18+ | [github.com/gitleaks](https://github.com/gitleaks/gitleaks) |
| Checkov | 3.x | `pip install checkov` |
| Kubesec | 2.x | [kubesec.io](https://kubesec.io) |
| Vault CLI | 1.15+ | [vaultproject.io](https://vaultproject.io) |

### 📊 SRE / Operations

| Tool | Version | Install |
|------|---------|---------|
| k6 | 0.49+ | [k6.io](https://k6.io) |
| Prometheus CLI | 2.49+ | [prometheus.io](https://prometheus.io) |
| Grafana CLI | 10.x | [grafana.com](https://grafana.com) |
| stern | 1.28+ | [github.com/stern/stern](https://github.com/stern/stern) |
| kubectx/kubens | Latest | [github.com/ahmetb/kubectx](https://github.com/ahmetb/kubectx) |

---

## Minimum Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 4 cores | 8+ cores |
| RAM | 16 GB | 32 GB |
| Disk | 50 GB free | 100 GB SSD |
| OS | Windows 10/11, macOS 12+, Ubuntu 20.04+ | Ubuntu 22.04 LTS |

---

## VS Code Extensions (Recommended)

```json
{
  "recommendations": [
    "ms-kubernetes-tools.vscode-kubernetes-tools",
    "hashicorp.terraform",
    "ms-azuretools.vscode-docker",
    "redhat.vscode-yaml",
    "bierner.markdown-mermaid",
    "eamodio.gitlens",
    "ms-python.python",
    "golang.go",
    "vscjava.vscode-java-pack",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "ms-vscode-remote.remote-containers"
  ]
}
```

---

## Environment Variables Required

```bash
# AWS
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"

# Azure
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"

# GCP
export GOOGLE_PROJECT="your-project-id"
export GOOGLE_CREDENTIALS="path/to/service-account.json"

# Platform
export NEXACOMMERCE_ENV="dev"
export REGISTRY="your-ecr-registry-url"
```

Store secrets in `.env.local` (gitignored) or use [direnv](https://direnv.net/).

---

## Next Steps

- [Local Development Setup](local-development.md)
- [Docker Setup](docker-setup.md)
- [Kubernetes Setup](kubernetes-setup.md)
- [AWS Setup](aws-setup.md)
- [Azure Setup](azure-setup.md)
- [GCP Setup](gcp-setup.md)
