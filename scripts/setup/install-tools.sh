#!/bin/bash
# ============================================================
# NexaCommerce — Local Development Setup Script
# Installs all required tools for Linux/macOS
# ============================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

log_info "Detected OS: $OS / $ARCH"

# ── Check prerequisites ───────────────────────────────────
check_command() {
    if command -v "$1" &>/dev/null; then
        log_success "$1 already installed: $(command -v $1)"
        return 0
    fi
    return 1
}

# ── Install Docker ────────────────────────────────────────
install_docker() {
    if check_command docker; then return; fi
    log_info "Installing Docker..."
    if [[ "$OS" == "Linux" ]]; then
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "$USER"
        log_success "Docker installed. Please log out and back in for group changes."
    elif [[ "$OS" == "Darwin" ]]; then
        log_warn "Please install Docker Desktop from https://docker.com/products/docker-desktop"
    fi
}

# ── Install kubectl ───────────────────────────────────────
install_kubectl() {
    if check_command kubectl; then return; fi
    log_info "Installing kubectl..."
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    if [[ "$OS" == "Linux" ]]; then
        curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
    elif [[ "$OS" == "Darwin" ]]; then
        brew install kubectl
    fi
    log_success "kubectl installed: $(kubectl version --client --short 2>/dev/null)"
}

# ── Install Helm ──────────────────────────────────────────
install_helm() {
    if check_command helm; then return; fi
    log_info "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    log_success "Helm installed: $(helm version --short)"
}

# ── Install Terraform ─────────────────────────────────────
install_terraform() {
    if check_command terraform; then return; fi
    log_info "Installing Terraform..."
    if [[ "$OS" == "Linux" ]]; then
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update && sudo apt install -y terraform
    elif [[ "$OS" == "Darwin" ]]; then
        brew tap hashicorp/tap && brew install hashicorp/tap/terraform
    fi
    log_success "Terraform installed: $(terraform version -json | jq -r .terraform_version)"
}

# ── Install AWS CLI ───────────────────────────────────────
install_awscli() {
    if check_command aws; then return; fi
    log_info "Installing AWS CLI..."
    if [[ "$OS" == "Linux" ]]; then
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip && sudo ./aws/install
        rm -rf awscliv2.zip aws/
    elif [[ "$OS" == "Darwin" ]]; then
        brew install awscli
    fi
    log_success "AWS CLI installed: $(aws --version)"
}

# ── Install Azure CLI ─────────────────────────────────────
install_azcli() {
    if check_command az; then return; fi
    log_info "Installing Azure CLI..."
    if [[ "$OS" == "Linux" ]]; then
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    elif [[ "$OS" == "Darwin" ]]; then
        brew install azure-cli
    fi
    log_success "Azure CLI installed: $(az version --query '"azure-cli"' -o tsv)"
}

# ── Install gcloud CLI ────────────────────────────────────
install_gcloud() {
    if check_command gcloud; then return; fi
    log_info "Installing gcloud CLI..."
    if [[ "$OS" == "Linux" ]]; then
        curl https://sdk.cloud.google.com | bash
        exec -l "$SHELL"
    elif [[ "$OS" == "Darwin" ]]; then
        brew install --cask google-cloud-sdk
    fi
    log_success "gcloud CLI installed"
}

# ── Install ArgoCD CLI ────────────────────────────────────
install_argocd() {
    if check_command argocd; then return; fi
    log_info "Installing ArgoCD CLI..."
    ARGOCD_VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | jq -r .tag_name)
    if [[ "$OS" == "Linux" ]]; then
        curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
        chmod +x argocd && sudo mv argocd /usr/local/bin/
    elif [[ "$OS" == "Darwin" ]]; then
        brew install argocd
    fi
    log_success "ArgoCD CLI installed: $(argocd version --client --short)"
}

# ── Install k9s ───────────────────────────────────────────
install_k9s() {
    if check_command k9s; then return; fi
    log_info "Installing k9s..."
    if [[ "$OS" == "Darwin" ]]; then
        brew install derailed/k9s/k9s
    else
        curl -sS https://webinstall.dev/k9s | bash
    fi
    log_success "k9s installed"
}

# ── Install k6 (load testing) ─────────────────────────────
install_k6() {
    if check_command k6; then return; fi
    log_info "Installing k6..."
    if [[ "$OS" == "Linux" ]]; then
        sudo gpg -k
        sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
            --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
        echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" \
            | sudo tee /etc/apt/sources.list.d/k6.list
        sudo apt update && sudo apt install -y k6
    elif [[ "$OS" == "Darwin" ]]; then
        brew install k6
    fi
    log_success "k6 installed: $(k6 version)"
}

# ── Configure local environment ───────────────────────────
configure_local() {
    log_info "Configuring local environment..."

    # Copy .env.example if .env.local doesn't exist
    if [[ ! -f ".env.local" ]]; then
        cp .env.example .env.local
        log_warn "Created .env.local from .env.example — please fill in your values"
    fi

    # Create local kubeconfig directory
    mkdir -p ~/.kube

    log_success "Local environment configured"
}

# ── Main ──────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  NexaCommerce — Development Setup        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
    echo ""

    install_docker
    install_kubectl
    install_helm
    install_terraform
    install_awscli
    install_azcli
    install_gcloud
    install_argocd
    install_k9s
    install_k6
    configure_local

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Setup Complete! 🎉                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Edit .env.local with your credentials"
    echo "  2. Run: make dev-up"
    echo "  3. Visit: http://localhost:3000"
    echo ""
}

main "$@"
