# ArgoCD Setup Guide — NexaCommerce

## Overview
ArgoCD is the GitOps continuous delivery tool for NexaCommerce. It watches the Git repository and automatically syncs Kubernetes manifests.

---

## Installation

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.0/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available deployment \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=300s

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

---

## Access ArgoCD UI

```bash
# Port-forward (local access)
kubectl port-forward svc/argocd-server -n argocd 8888:443 &
# Access: https://localhost:8888
# Username: admin
# Password: (from above command)

# Or expose via LoadBalancer
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'
```

---

## Configure SSO (GitHub OIDC)

```bash
# Edit ArgoCD configmap
kubectl edit configmap argocd-cm -n argocd
```

Add to data:
```yaml
data:
  url: https://argocd.nexacommerce.com
  oidc.config: |
    name: GitHub
    issuer: https://token.actions.githubusercontent.com
    clientID: <github-oauth-app-client-id>
    clientSecret: $oidc.github.clientSecret
    requestedScopes: ["openid", "profile", "email"]
```

---

## Install ArgoCD CLI

```bash
# Linux/macOS
curl -sSL -o argocd \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd && sudo mv argocd /usr/local/bin/

# Windows (PowerShell)
Invoke-WebRequest -Uri https://github.com/argoproj/argo-cd/releases/latest/download/argocd-windows-amd64.exe -OutFile argocd.exe

# Login
argocd login argocd.nexacommerce.com \
  --username admin \
  --password <password>
```

---

## Bootstrap App-of-Apps

```bash
# Apply root application (bootstraps all environments)
kubectl apply -f argocd/root-app.yaml

# Watch sync status
argocd app list
argocd app get nexacommerce-root

# Manually sync if needed
argocd app sync nexacommerce-root
argocd app sync nexacommerce-dev
```

---

## Register Clusters (Multi-Cloud)

```bash
# Add AWS EKS cluster
kubectl config use-context arn:aws:eks:us-east-1:ACCOUNT:cluster/nexacommerce-prod
argocd cluster add arn:aws:eks:us-east-1:ACCOUNT:cluster/nexacommerce-prod \
  --name nexacommerce-prod-aws

# Add Azure AKS cluster
kubectl config use-context nexacommerce-prod-aks
argocd cluster add nexacommerce-prod-aks \
  --name nexacommerce-prod-azure

# Add GCP GKE cluster
kubectl config use-context gke_PROJECT_us-central1_nexacommerce-prod
argocd cluster add gke_PROJECT_us-central1_nexacommerce-prod \
  --name nexacommerce-prod-gcp

# List registered clusters
argocd cluster list
```

---

## ArgoCD Projects

```bash
# Create production project with restrictions
argocd proj create nexacommerce-prod \
  --description "Production environment" \
  --dest https://eks-prod.us-east-1.eks.amazonaws.com,nexacommerce-prod \
  --src https://github.com/your-org/nexacommerce.git \
  --allow-cluster-resource Namespace \
  --deny-cluster-resource "" \
  --orphaned-resources-warn

# Create dev project
argocd proj create nexacommerce-dev \
  --description "Development environment" \
  --dest https://eks-dev.us-east-1.eks.amazonaws.com,nexacommerce-dev \
  --src https://github.com/your-org/nexacommerce.git
```

---

## Useful ArgoCD Commands

```bash
# List all applications
argocd app list

# Get application details
argocd app get nexacommerce-prod

# Sync application
argocd app sync nexacommerce-prod --prune

# Rollback to previous revision
argocd app rollback nexacommerce-prod

# View application diff
argocd app diff nexacommerce-prod

# Delete application (keeps K8s resources)
argocd app delete nexacommerce-prod --cascade=false

# Force hard refresh
argocd app get nexacommerce-prod --hard-refresh
```

---

## ArgoCD Image Updater

```bash
# Install ArgoCD Image Updater
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

# Configure ECR credentials
kubectl create secret docker-registry ecr-credentials \
  --docker-server=ACCOUNT.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password) \
  -n argocd
```

---

## Related
- [GitOps Flow Diagram](../diagrams/gitops-flow.mmd)
- [ArgoCD Apps](../../argocd/)
- [Kubernetes Setup](kubernetes-setup.md)
