# Local Development Setup — NexaCommerce

## Overview
Get the full NexaCommerce platform running locally in under 30 minutes.

- **Windows**: Uses WSL2 + Docker Desktop
- **Linux/macOS**: Native Docker + tools

---

## Part 1 — Windows Setup

### Step 1: Install WSL2

```powershell
# Run in PowerShell as Administrator
wsl --install
wsl --set-default-version 2
wsl --install -d Ubuntu-22.04
```

Restart your machine, then set up Ubuntu user account.

### Step 2: Install Docker Desktop (Windows)

1. Download [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
2. Enable **WSL2 backend** during installation
3. In Docker Desktop → Settings → Resources → WSL Integration → Enable Ubuntu-22.04
4. Verify:
```powershell
docker --version
docker compose version
```

### Step 3: Install Tools on Windows (via winget)

```powershell
# Git
winget install Git.Git

# VS Code
winget install Microsoft.VisualStudioCode

# Node.js LTS
winget install OpenJS.NodeJS.LTS

# Python
winget install Python.Python.3.11

# kubectl
winget install Kubernetes.kubectl

# Helm
winget install Helm.Helm

# Terraform
winget install Hashicorp.Terraform

# AWS CLI
winget install Amazon.AWSCLI

# Azure CLI
winget install Microsoft.AzureCLI

# k9s (Kubernetes TUI)
winget install derailed.k9s
```

### Step 4: Install Tools in WSL2 (Ubuntu)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install base tools
sudo apt install -y curl wget git build-essential jq unzip

# Install Go 1.22
wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc

# Install Java 17 (Temurin)
sudo apt install -y wget apt-transport-https
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo apt-key add -
echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" \
  | sudo tee /etc/apt/sources.list.d/adoptium.list
sudo apt update && sudo apt install -y temurin-17-jdk

# Install Maven
sudo apt install -y maven

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install k9s
curl -sS https://webinstall.dev/k9s | bash

# Install kubectx + kubens
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
```

---

## Part 2 — Linux (Ubuntu/Debian) Setup

```bash
# Install Docker Engine
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose plugin
sudo apt install -y docker-compose-plugin

# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install Python 3.11
sudo apt install -y python3.11 python3.11-venv python3-pip

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

---

## Part 3 — Start Local Platform

### Clone Repository

```bash
git clone https://github.com/your-org/nexacommerce.git
cd nexacommerce
```

### Configure Local Environment

```bash
# Copy environment template
cp .env.example .env.local

# Optional: also create .env for docker compose variable loading
cp .env.example .env

# Edit with your values
nano .env.local
```

### Start All Services

```bash
# Start full local stack
make dev-up

# Or start specific services
docker compose up -d postgres redis kafka elasticsearch
docker compose up -d auth-service product-service cart-service
docker compose up -d frontend
```

### Verify Services

```bash
# Check all containers running
docker compose ps

# Check service health
curl http://localhost:3000               # Frontend
curl http://localhost:8080/health/live   # API Gateway
curl http://localhost:8081/health/live   # Auth Service
curl http://localhost:8082/actuator/health # Product Service
```

### Access Local Services

| Service | URL |
|---------|-----|
| Frontend | http://localhost:3000 |
| API Gateway | http://localhost:8080 |
| Grafana | http://localhost:3001 (admin/admin) |
| Prometheus | http://localhost:9090 |
| Loki (API) | http://localhost:3100 |
| Kafka UI | http://localhost:8090 |
| MailHog | http://localhost:8025 |

---

## Part 4 — Local Kubernetes (Kind)

```bash
# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# Create local cluster
kind create cluster --name nexacommerce-local

# Load local images
kind load docker-image nexacommerce/auth-service:local --name nexacommerce-local

# Deploy dev overlay to local cluster (adjust as needed)
kubectl apply -k kubernetes/overlays/dev

# Access via port-forward
kubectl port-forward svc/frontend 3000:80 -n nexacommerce-local
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Docker not starting | Ensure WSL2 is enabled, restart Docker Desktop |
| Port already in use | `sudo lsof -i :PORT` then kill process |
| Out of memory | Increase Docker Desktop memory to 8GB+ |
| Kafka not connecting | Wait 30s for Kafka to fully start |
| DB connection refused | Check `.env.local` DB credentials |

---

## Next Steps

- [Docker Setup Details](docker-setup.md)
- [Kubernetes Setup](kubernetes-setup.md)
- [AWS Setup](aws-setup.md)
