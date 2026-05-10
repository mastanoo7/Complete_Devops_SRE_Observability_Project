# ============================================================
# NexaCommerce — Enterprise Makefile
# Developer shortcuts for local dev, testing, and deployment
# ============================================================

.PHONY: help setup-local dev-up dev-down test-all build-all \
        deploy-dev deploy-staging deploy-prod \
        tf-init tf-plan tf-apply tf-destroy \
        k8s-apply k8s-delete lint fmt \
        docker-build docker-push \
        argocd-sync argocd-diff \
        security-scan chaos-run \
        logs-tail metrics-check slo-check

# ── Colors ────────────────────────────────────────────────
CYAN    := \033[0;36m
GREEN   := \033[0;32m
YELLOW  := \033[0;33m
RED     := \033[0;31m
RESET   := \033[0m

# ── Variables ─────────────────────────────────────────────
PROJECT         := nexacommerce
REGISTRY        := $(or $(REGISTRY), 123456789.dkr.ecr.us-east-1.amazonaws.com)
IMAGE_TAG       := $(or $(IMAGE_TAG), $(shell git rev-parse --short HEAD))
ENVIRONMENT     := $(or $(ENVIRONMENT), dev)
CLUSTER_NAME    := $(PROJECT)-$(ENVIRONMENT)
TF_DIR          := terraform/environments/$(ENVIRONMENT)
K8S_OVERLAY     := kubernetes/overlays/$(ENVIRONMENT)
NAMESPACE       := $(PROJECT)-$(ENVIRONMENT)
# Keep this aligned with directories present under backend/ and local stack in docker-compose.yml.
SERVICES        := api-gateway auth-service product-service cart-service \
                   order-service payment-service inventory-service \
                   search-service notification-service frontend

# ── Help ──────────────────────────────────────────────────
help: ## Show this help message
	@echo ""
	@echo "$(CYAN)NexaCommerce — Developer Commands$(RESET)"
	@echo "$(CYAN)====================================$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-28s$(RESET) %s\n", $$1, $$2}'
	@echo ""

# ── Local Development ─────────────────────────────────────
setup-local: ## Install all local development tools
	@echo "$(CYAN)Setting up local development environment...$(RESET)"
	@bash scripts/setup/install-tools.sh
	@bash scripts/setup/configure-local.sh
	@echo "$(GREEN)✓ Local setup complete$(RESET)"

dev-up: ## Start all services locally with Docker Compose
	@echo "$(CYAN)Starting local development environment...$(RESET)"
	docker compose -f docker-compose.yml -f docker-compose.override.yml up -d
	@echo "$(GREEN)✓ Services running at http://localhost:3000$(RESET)"

dev-down: ## Stop all local services
	docker compose down --remove-orphans

dev-logs: ## Tail logs for all local services
	docker compose logs -f --tail=100

dev-reset: ## Reset local environment (removes volumes)
	docker compose down -v --remove-orphans
	@echo "$(YELLOW)⚠ All local data removed$(RESET)"

# ── Build ─────────────────────────────────────────────────
build-all: ## Build all service Docker images
	@echo "$(CYAN)Building all services (tag: $(IMAGE_TAG))...$(RESET)"
	@for svc in $(SERVICES); do \
		echo "  Building $$svc..."; \
		docker build \
			--build-arg BUILD_DATE=$(shell date -u +%Y-%m-%dT%H:%M:%SZ) \
			--build-arg GIT_COMMIT=$(IMAGE_TAG) \
			--cache-from $(REGISTRY)/$$svc:latest \
			-t $(REGISTRY)/$$svc:$(IMAGE_TAG) \
			-t $(REGISTRY)/$$svc:latest \
			backend/$$svc/ 2>&1 | tail -3; \
	done
	@echo "$(GREEN)✓ All images built$(RESET)"

build-service: ## Build single service: make build-service SVC=auth-service
	@echo "$(CYAN)Building $(SVC)...$(RESET)"
	docker build \
		--build-arg GIT_COMMIT=$(IMAGE_TAG) \
		-t $(REGISTRY)/$(SVC):$(IMAGE_TAG) \
		backend/$(SVC)/

docker-push: ## Push all images to registry
	@echo "$(CYAN)Pushing images to $(REGISTRY)...$(RESET)"
	@aws ecr get-login-password --region us-east-1 | \
		docker login --username AWS --password-stdin $(REGISTRY)
	@for svc in $(SERVICES); do \
		docker push $(REGISTRY)/$$svc:$(IMAGE_TAG); \
		docker push $(REGISTRY)/$$svc:latest; \
	done
	@echo "$(GREEN)✓ All images pushed$(RESET)"

# ── Testing ───────────────────────────────────────────────
test-all: ## Run all tests (unit + integration)
	@echo "$(CYAN)Running full test suite...$(RESET)"
	@$(MAKE) test-unit
	@$(MAKE) test-integration
	@echo "$(GREEN)✓ All tests passed$(RESET)"

test-unit: ## Run unit tests for all services
	@for svc in $(SERVICES); do \
		echo "  Testing $$svc..."; \
		cd backend/$$svc && $(MAKE) test-unit 2>&1 | tail -5; cd ../..; \
	done

test-integration: ## Run integration tests
	@echo "$(YELLOW)Integration tests are not wired yet: missing docker-compose.test.yml$(RESET)"
	@echo "$(YELLOW)Add docker-compose.test.yml (or update this target) to enable integration tests.$(RESET)"
	@exit 1

test-e2e: ## Run E2E tests with Playwright
	cd frontend && npx playwright test --reporter=html

test-load: ## Run k6 load tests
	k6 run scripts/load-testing/smoke-test.js
	k6 run scripts/load-testing/load-test.js

# ── Linting & Formatting ──────────────────────────────────
lint: ## Lint all code
	@echo "$(CYAN)Linting all services...$(RESET)"
	@$(MAKE) lint-go lint-java lint-node lint-python lint-tf lint-k8s
	@echo "$(GREEN)✓ Lint passed$(RESET)"

lint-go:
	golangci-lint run ./backend/auth-service/...

lint-java:
	cd backend/product-service && mvn checkstyle:check
	cd backend/order-service && mvn checkstyle:check

lint-node:
	cd backend/api-gateway && npm run lint
	cd backend/cart-service && npm run lint
	cd backend/payment-service && npm run lint
	cd backend/search-service && npm run lint
	cd backend/notification-service && npm run lint
	cd frontend && npm run lint

lint-python:
	cd backend/inventory-service && python -m compileall .

lint-tf: ## Lint Terraform code
	terraform fmt -check -recursive terraform/
	tflint --recursive terraform/

lint-k8s: ## Lint Kubernetes manifests
	kubeval --recursive kubernetes/base/
	kube-score score kubernetes/base/**/*.yaml

fmt: ## Auto-format all code
	terraform fmt -recursive terraform/
	cd backend/auth-service && gofmt -w .
	cd frontend && npm run format

# ── Terraform ─────────────────────────────────────────────
tf-init: ## Initialize Terraform for environment
	@echo "$(CYAN)Initializing Terraform (env: $(ENVIRONMENT))...$(RESET)"
	cd $(TF_DIR) && terraform init -upgrade

tf-plan: ## Plan Terraform changes
	@echo "$(CYAN)Planning Terraform (env: $(ENVIRONMENT))...$(RESET)"
	cd $(TF_DIR) && terraform plan -out=tfplan

tf-apply: ## Apply Terraform changes (requires approval)
	@echo "$(YELLOW)⚠ Applying Terraform to $(ENVIRONMENT)...$(RESET)"
	cd $(TF_DIR) && terraform apply tfplan

tf-destroy: ## Destroy Terraform resources (DANGEROUS)
	@echo "$(RED)⚠ DESTROYING $(ENVIRONMENT) infrastructure!$(RESET)"
	@read -p "Type environment name to confirm: " confirm; \
		[ "$$confirm" = "$(ENVIRONMENT)" ] || (echo "Aborted" && exit 1)
	cd $(TF_DIR) && terraform destroy

tf-output: ## Show Terraform outputs
	cd $(TF_DIR) && terraform output

# ── Kubernetes ────────────────────────────────────────────
k8s-apply: ## Apply Kubernetes manifests for environment
	@echo "$(CYAN)Applying K8s manifests (env: $(ENVIRONMENT))...$(RESET)"
	kubectl apply -k $(K8S_OVERLAY)

k8s-delete: ## Delete Kubernetes resources for environment
	kubectl delete -k $(K8S_OVERLAY)

k8s-diff: ## Show diff of pending K8s changes
	kubectl diff -k $(K8S_OVERLAY)

k8s-status: ## Show status of all pods in namespace
	kubectl get pods -n $(NAMESPACE) -o wide

k8s-events: ## Show recent K8s events
	kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -30

k8s-rollout: ## Check rollout status for a deployment
	kubectl rollout status deployment/$(SVC) -n $(NAMESPACE)

k8s-rollback: ## Rollback a deployment: make k8s-rollback SVC=auth-service
	kubectl rollout undo deployment/$(SVC) -n $(NAMESPACE)

# ── ArgoCD ────────────────────────────────────────────────
argocd-sync: ## Sync ArgoCD application
	argocd app sync $(PROJECT)-$(ENVIRONMENT) --prune

argocd-diff: ## Show ArgoCD diff
	argocd app diff $(PROJECT)-$(ENVIRONMENT)

argocd-status: ## Show ArgoCD app status
	argocd app get $(PROJECT)-$(ENVIRONMENT)

argocd-rollback: ## Rollback ArgoCD to previous revision
	argocd app rollback $(PROJECT)-$(ENVIRONMENT)

# ── Deployment ────────────────────────────────────────────
deploy-dev: ## Deploy to DEV environment
	@echo "$(CYAN)Deploying to DEV...$(RESET)"
	ENVIRONMENT=dev $(MAKE) k8s-apply
	@echo "$(GREEN)✓ DEV deployment complete$(RESET)"

deploy-staging: ## Deploy to STAGING environment
	@echo "$(CYAN)Deploying to STAGING...$(RESET)"
	ENVIRONMENT=staging $(MAKE) k8s-apply
	@$(MAKE) test-e2e
	@echo "$(GREEN)✓ STAGING deployment complete$(RESET)"

deploy-prod: ## Deploy to PRODUCTION (requires SRE approval)
	@echo "$(YELLOW)⚠ Deploying to PRODUCTION...$(RESET)"
	@read -p "Confirm production deployment (yes/no): " confirm; \
		[ "$$confirm" = "yes" ] || (echo "Aborted" && exit 1)
	ENVIRONMENT=prod $(MAKE) argocd-sync
	@echo "$(GREEN)✓ PRODUCTION deployment initiated$(RESET)"

# ── Security ──────────────────────────────────────────────
security-scan: ## Run full security scan
	@echo "$(CYAN)Running security scans...$(RESET)"
	@$(MAKE) scan-images scan-secrets scan-iac scan-k8s
	@echo "$(GREEN)✓ Security scan complete$(RESET)"

scan-images: ## Scan container images with Trivy
	@for svc in $(SERVICES); do \
		trivy image --exit-code 1 --severity CRITICAL \
			$(REGISTRY)/$$svc:$(IMAGE_TAG); \
	done

scan-secrets: ## Scan for secrets with GitLeaks
	gitleaks detect --source . --verbose

scan-iac: ## Scan IaC with Checkov
	checkov -d terraform/ --framework terraform
	checkov -d kubernetes/ --framework kubernetes

scan-k8s: ## Scan K8s manifests with Kubesec
	find kubernetes/base -name "*.yaml" | xargs -I{} kubesec scan {}

# ── Chaos Engineering ─────────────────────────────────────
chaos-run: ## Run chaos experiment: make chaos-run EXP=pod-delete
	@echo "$(YELLOW)⚠ Running chaos experiment: $(EXP)$(RESET)"
	kubectl apply -f chaos-engineering/experiments/$(EXP).yaml

chaos-list: ## List available chaos experiments
	ls chaos-engineering/experiments/

chaos-stop: ## Stop all running chaos experiments
	kubectl delete chaosexperiments --all -n $(NAMESPACE)

# ── Observability ─────────────────────────────────────────
logs-tail: ## Tail logs for a service: make logs-tail SVC=auth-service
	kubectl logs -f -l app=$(SVC) -n $(NAMESPACE) --all-containers

metrics-check: ## Check Prometheus metrics for a service
	kubectl port-forward svc/prometheus 9090:9090 -n monitoring &
	@echo "$(GREEN)Prometheus available at http://localhost:9090$(RESET)"

grafana-open: ## Open Grafana dashboard
	kubectl port-forward svc/grafana 3000:3000 -n monitoring &
	@echo "$(GREEN)Grafana available at http://localhost:3000$(RESET)"

slo-check: ## Check SLO compliance for all services
	@bash scripts/sre/check-slos.sh

# ── Utilities ─────────────────────────────────────────────
kubeconfig-aws: ## Configure kubectl for AWS EKS
	aws eks update-kubeconfig \
		--name $(CLUSTER_NAME) \
		--region us-east-1

kubeconfig-azure: ## Configure kubectl for Azure AKS
	az aks get-credentials \
		--resource-group $(PROJECT)-$(ENVIRONMENT)-rg \
		--name $(CLUSTER_NAME)

kubeconfig-gcp: ## Configure kubectl for GCP GKE
	gcloud container clusters get-credentials $(CLUSTER_NAME) \
		--region us-central1

clean: ## Clean build artifacts
	find . -name "*.tfplan" -delete
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	docker system prune -f

version: ## Show tool versions
	@echo "$(CYAN)Tool Versions:$(RESET)"
	@echo "  kubectl:   $$(kubectl version --client --short 2>/dev/null)"
	@echo "  terraform: $$(terraform version -json | jq -r .terraform_version)"
	@echo "  helm:      $$(helm version --short)"
	@echo "  argocd:    $$(argocd version --client --short)"
	@echo "  docker:    $$(docker --version)"
