# NexaCommerce Installation Guide

This guide explains how to start from scratch, run the platform locally, test it, and deploy to `dev`, `staging`, and `prod`.

---

## 1) Start From Scratch

## 1.1 Clone the Repository

```bash
git clone https://github.com/your-org/nexacommerce.git
cd nexacommerce
```

## 1.2 Install Required Tools

Minimum tool versions:

- Git `2.40+`
- Docker Desktop / Docker Engine `24+` with `docker compose`
- Node.js `20+` and npm
- Python `3.11+`
- Java `17` and Maven `3.9+`
- kubectl `1.29+`
- Helm `3.14+`
- Terraform `1.7+`
- AWS CLI `2.x`
- Azure CLI `2.57+`
- gcloud CLI `460+`
- ArgoCD CLI `2.10+`

Tip: refer to `docs/setup/prerequisites.md` for role-based tooling details.

## 1.3 Configure Environment Files

```bash
# Local app env
cp .env.example .env.local

# Docker Compose picks .env automatically
cp .env.example .env
```

Edit `.env.local` and `.env` with your local values (passwords, keys, URLs).

---

## 2) Run Locally (End-to-End)

## 2.1 Start Local Stack

```bash
make dev-up
```

This starts frontend, API gateway, core backend services, data services, and observability stack via Docker Compose.

## 2.2 Verify Containers

```bash
docker compose ps
docker compose logs -f --tail=100
```

## 2.3 Verify Service Health

```bash
curl http://localhost:3000
curl http://localhost:8080/health/live
curl http://localhost:8081/health/live
curl http://localhost:8082/actuator/health
curl http://localhost:8084/actuator/health
```

## 2.4 Local URLs

- Frontend: `http://localhost:3000`
- API Gateway: `http://localhost:8080`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3001`
- Kafka UI: `http://localhost:8090`
- MailHog: `http://localhost:8025`

## 2.5 Stop Local Stack

```bash
make dev-down
```

---

## 3) Test Locally

Run these checks before pushing code:

## 3.1 Frontend Checks

```bash
cd frontend
npm install
npm run type-check
npm run lint
npm run build
cd ..
```

## 3.2 Java Service Builds

```bash
cd backend/product-service
mvn -q -DskipTests package
cd ../order-service
mvn -q -DskipTests package
cd ../..
```

## 3.3 Node Service Syntax/Lint Checks

```bash
cd backend/api-gateway && npm install && npm run lint && cd ../..
cd backend/cart-service && npm install && npm run lint && cd ../..
cd backend/payment-service && npm install && npm run lint && cd ../..
cd backend/notification-service && npm install && npm run lint && cd ../..
```

## 3.4 Python Service Check

```bash
cd backend/inventory-service
python -m pip install -r requirements.txt
python -m compileall .
cd ../..
```

---

## 4) Deploy to DEV

Use `dev` for shared integration testing.

## 4.1 Configure Cloud Access

```bash
aws configure
az login
gcloud auth login
gcloud config set project <project-id>
```

## 4.2 Provision DEV Infrastructure (Terraform)

```bash
cd terraform/environments/dev
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
cd ../../..
```

## 4.3 Configure kubectl Context

```bash
aws eks update-kubeconfig --name nexacommerce-dev --region us-east-1
kubectl get nodes
```

## 4.4 Deploy Manifests / Sync GitOps

```bash
# Option A: direct apply
make deploy-dev

# Option B: ArgoCD sync (if configured)
argocd app sync nexacommerce-dev --prune
```

## 4.5 Verify DEV

```bash
kubectl get pods -n nexacommerce-dev
kubectl get svc -n nexacommerce-dev
```

---

## 5) Deploy to STAGING

Use `staging` for pre-production validation and release sign-off.

## 5.1 Provision STAGING Infrastructure

```bash
cd terraform/environments/staging
terraform init
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"
cd ../../..
```

## 5.2 Deploy to STAGING

```bash
make deploy-staging
```

Or with ArgoCD:

```bash
argocd app sync nexacommerce-staging --prune
```

## 5.3 Validate STAGING

- Run smoke tests on critical flows (auth, catalog, cart, checkout).
- Run E2E tests:

```bash
cd frontend
npx playwright test --reporter=html
cd ..
```

- Confirm no critical alerts in monitoring.

---

## 6) Deploy to PROD

Production requires change approval and rollback readiness.

## 6.1 Pre-Deployment Checklist

- Release branch/tag approved
- CI green (build, lint, security, infra checks)
- Migration steps reviewed
- Rollback plan confirmed
- On-call/SRE notified

## 6.2 Provision/Update PROD Infrastructure

```bash
cd terraform/environments/prod
terraform init
terraform plan -var-file="prod.tfvars" -out=tfplan
terraform apply tfplan
cd ../../..
```

## 6.3 Deploy Application to PROD

```bash
make deploy-prod
```

Or with ArgoCD:

```bash
argocd app sync nexacommerce-prod --prune
```

## 6.4 Post-Deployment Verification

```bash
kubectl get pods -n nexacommerce-prod
kubectl rollout status deployment/auth-service -n nexacommerce-prod
kubectl rollout status deployment/product-service -n nexacommerce-prod
```

Then verify:

- Error rate, latency, saturation dashboards
- Business KPIs (checkout success, payment success)
- Logs/traces for new errors

---

## 7) Rollback Basics

If a deployment fails:

```bash
# Kubernetes rollback
kubectl rollout undo deployment/<service> -n <namespace>

# ArgoCD rollback
argocd app rollback <app-name>
```

Use detailed procedures in `runbooks/` and `docs/cicd/rollback-strategies.md`.

---

## 8) Troubleshooting Quick Tips

- Docker services failing: `docker compose logs -f --tail=200`
- Port conflict: stop process using the port, then restart stack
- Kubernetes issues: `kubectl describe pod <pod> -n <namespace>`
- Terraform lock issue: `terraform force-unlock <LOCK_ID>` (with caution)

---

## 9) Related Docs

- `README.md`
- `docs/setup/local-development.md`
- `docs/setup/kubernetes-setup.md`
- `docs/setup/terraform-setup.md`
- `docs/setup/argocd-setup.md`
- `docs/cicd/deployment-strategies.md`
- `docs/cicd/rollback-strategies.md`

