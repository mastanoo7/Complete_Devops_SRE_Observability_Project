# Kubernetes Setup Guide — NexaCommerce

## Overview
This guide covers setting up Kubernetes clusters for all environments using EKS, AKS, and GKE.

---

## Prerequisites

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# Install Kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/

# Install k9s (optional but recommended)
curl -sS https://webinstall.dev/k9s | bash
```

---

## Local Kubernetes (Kind)

```bash
# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# Create local cluster
cat <<EOF | kind create cluster --name nexacommerce-local --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
        hostPort: 443
  - role: worker
  - role: worker
  - role: worker
EOF

# Verify cluster
kubectl cluster-info --context kind-nexacommerce-local
kubectl get nodes
```

---

## AWS EKS Setup

```bash
# Configure kubectl for EKS
aws eks update-kubeconfig \
  --name nexacommerce-dev \
  --region us-east-1

# Verify access
kubectl get nodes
kubectl get pods -A

# Install core components
# 1. Istio
istioctl install --set profile=production -y
kubectl label namespace nexacommerce-prod istio-injection=enabled

# 2. Cert-Manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# 3. AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=nexacommerce-dev \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# 4. Cluster Autoscaler
helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName=nexacommerce-dev \
  --set awsRegion=us-east-1
```

---

## Install Platform Components

```bash
# Create namespaces
kubectl apply -f kubernetes/base/namespaces.yaml

# Install Kong API Gateway
helm repo add kong https://charts.konghq.com
helm install kong kong/ingress \
  --namespace kong \
  --create-namespace \
  --set ingressController.installCRDs=false

# Install Vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault \
  --namespace security \
  --create-namespace \
  --set server.ha.enabled=true \
  --set server.ha.replicas=3

# Install Falco
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  --namespace security \
  --set driver.kind=ebpf \
  --set falcosidekick.enabled=true

# Install Kyverno
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace

# Apply Kyverno policies
kubectl apply -f security/kyverno/policies.yaml

# Install OPA Gatekeeper
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace

# Apply OPA constraints
kubectl apply -f security/opa/gatekeeper-constraints.yaml
```

---

## Deploy Applications

```bash
# Apply base manifests
kubectl apply -k kubernetes/base/

# Apply environment overlay
kubectl apply -k kubernetes/overlays/dev/

# Or use ArgoCD (recommended)
kubectl apply -f argocd/root-app.yaml
argocd app sync nexacommerce-dev

# Verify all pods running
kubectl get pods -n nexacommerce-dev
kubectl get svc -n nexacommerce-dev
```

---

## Useful kubectl Commands

```bash
# Get all resources in namespace
kubectl get all -n nexacommerce-prod

# Watch pod status
watch kubectl get pods -n nexacommerce-prod

# Get pod logs
kubectl logs -f deploy/auth-service -n nexacommerce-prod

# Execute into pod
kubectl exec -it deploy/auth-service -n nexacommerce-prod -- sh

# Port forward service
kubectl port-forward svc/frontend 3000:80 -n nexacommerce-prod

# Describe pod (for debugging)
kubectl describe pod <pod-name> -n nexacommerce-prod

# Get events sorted by time
kubectl get events -n nexacommerce-prod --sort-by='.lastTimestamp'

# Scale deployment
kubectl scale deployment/product-service --replicas=5 -n nexacommerce-prod

# Rolling restart
kubectl rollout restart deployment/auth-service -n nexacommerce-prod

# Check HPA status
kubectl get hpa -n nexacommerce-prod
```

---

## Related
- [Kubernetes Architecture](../architecture/kubernetes-architecture.md)
- [ArgoCD Setup](argocd-setup.md)
- [Monitoring Setup](monitoring-setup.md)
