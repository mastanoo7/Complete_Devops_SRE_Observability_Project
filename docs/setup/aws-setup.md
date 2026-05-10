# AWS Setup Guide — NexaCommerce

## Prerequisites

```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
aws --version  # aws-cli/2.x.x

# Configure AWS credentials
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region: us-east-1
# Default output format: json

# Verify access
aws sts get-caller-identity
```

---

## Step 1: Bootstrap Terraform State

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket nexacommerce-tf-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket nexacommerce-tf-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket nexacommerce-tf-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms"
      }
    }]
  }'

# Create DynamoDB lock table
aws dynamodb create-table \
  --table-name nexacommerce-tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## Step 2: Deploy Infrastructure

```bash
# Deploy DEV environment
cd terraform/environments/dev
terraform init
terraform plan -var="db_master_password=YourPassword123!" \
               -var="redis_auth_token=YourRedisToken123456"
terraform apply -auto-approve \
               -var="db_master_password=YourPassword123!" \
               -var="redis_auth_token=YourRedisToken123456"

# Configure kubectl
aws eks update-kubeconfig \
  --name nexacommerce-dev \
  --region us-east-1

# Verify cluster access
kubectl get nodes
kubectl get pods -A
```

---

## Step 3: Install Core Platform Components

```bash
# Install Istio
istioctl install --set profile=production -y

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install Cert-Manager
kubectl apply -f \
  https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Install Kong
helm repo add kong https://charts.konghq.com
helm install kong kong/ingress -n kong --create-namespace

# Install Prometheus Stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/prometheus/values.yaml
```

---

## Step 4: Deploy Applications

```bash
# Bootstrap ArgoCD app-of-apps
kubectl apply -f argocd/root-app.yaml

# Watch ArgoCD sync
argocd app list
argocd app sync nexacommerce-dev

# Verify all pods running
kubectl get pods -n nexacommerce-dev
```

---

## Step 5: Configure DNS

```bash
# Get ALB DNS name
ALB_DNS=$(kubectl get svc -n kong kong-proxy \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create Route53 record
aws route53 change-resource-record-sets \
  --hosted-zone-id <YOUR_ZONE_ID> \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"api.nexacommerce.com\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$ALB_DNS\"}]
      }
    }]
  }"
```

---

## Useful AWS Commands

```bash
# List EKS clusters
aws eks list-clusters --region us-east-1

# Describe Aurora cluster
aws rds describe-db-clusters \
  --db-cluster-identifier nexacommerce-prod-aurora

# Check ECR repositories
aws ecr describe-repositories \
  --query 'repositories[*].repositoryName'

# View CloudWatch logs
aws logs tail /aws/eks/nexacommerce-prod/cluster --follow

# Check MSK Kafka brokers
aws kafka list-clusters --query 'ClusterInfoList[*].ClusterName'
```

---

## Related
- [Terraform Setup](terraform-setup.md)
- [Kubernetes Setup](kubernetes-setup.md)
- [ArgoCD Setup](argocd-setup.md)
