# Jenkins Pipeline — NexaCommerce

## Overview
Jenkins provides an alternative CI/CD pipeline for teams that prefer Jenkins over GitHub Actions, or for on-premises deployments.

---

## Jenkins Setup

### Install Jenkins (Kubernetes)

```bash
# Add Jenkins Helm repo
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install Jenkins
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --set controller.adminPassword=YourJenkinsPassword \
  --set controller.serviceType=LoadBalancer \
  --set persistence.size=20Gi \
  --set agent.enabled=true \
  --set agent.podName=jenkins-agent

# Get Jenkins URL
kubectl get svc jenkins -n jenkins
```

### Required Jenkins Plugins

```
- Pipeline
- Kubernetes Plugin
- Docker Pipeline
- AWS Credentials
- Blue Ocean
- SonarQube Scanner
- Slack Notification
- Git
- GitHub Integration
- Credentials Binding
- Timestamper
- Workspace Cleanup
```

---

## Pipeline Structure

The [`Jenkinsfile`](../../Jenkinsfile) at the repo root defines the full pipeline:

```
Stages:
1. Checkout
2. Pre-checks (lint + secret scan + IaC scan) — parallel
3. Unit Tests (Go + Java + Node + Python) — parallel
4. SonarQube Analysis
5. Build Docker Images — parallel per service
6. Container Security Scan (Trivy)
7. Push Images to ECR
8. Deploy to Environment (DEV/STAGING/PROD)
```

---

## Jenkins Credentials Configuration

Configure these in Jenkins → Manage Jenkins → Credentials:

| ID | Type | Description |
|----|------|-------------|
| `ecr-registry` | Secret text | ECR registry URL |
| `aws-ci-credentials` | AWS credentials | CI/CD IAM user |
| `sonarqube-token` | Secret text | SonarQube API token |
| `argocd-token` | Secret text | ArgoCD API token |
| `slack-webhook` | Secret text | Slack webhook URL |
| `gitops-token` | Username/password | GitHub token for manifest updates |

---

## Kubernetes Agent Configuration

Jenkins agents run as Kubernetes pods:

```groovy
// In Jenkinsfile
agent {
    kubernetes {
        yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: tools
    image: nexacommerce/ci-tools:latest
    command: [cat]
    tty: true
  - name: docker
    image: docker:24-dind
    securityContext:
      privileged: true
'''
    }
}
```

---

## Pipeline Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ENVIRONMENT` | `dev` | Target deployment environment |
| `SERVICES` | `all` | Services to build |
| `SKIP_TESTS` | `false` | Skip tests (emergency only) |
| `DRY_RUN` | `false` | Plan only, no deploy |

---

## Triggering Pipelines

```bash
# Trigger via Jenkins CLI
java -jar jenkins-cli.jar -s http://jenkins:8080 \
  build nexacommerce-pipeline \
  -p ENVIRONMENT=staging \
  -p SERVICES=auth-service,product-service

# Trigger via API
curl -X POST http://jenkins:8080/job/nexacommerce-pipeline/buildWithParameters \
  --user admin:$JENKINS_TOKEN \
  --data "ENVIRONMENT=staging&SERVICES=all"
```

---

## Shared Libraries

```groovy
// Load shared library in Jenkinsfile
@Library('nexacommerce-shared-lib') _

// Use shared functions
nexacommerce.buildService('auth-service', IMAGE_TAG)
nexacommerce.scanImage('auth-service', IMAGE_TAG)
nexacommerce.deployToEnvironment('dev', IMAGE_TAG)
```

---

## Related Files
- [`Jenkinsfile`](../../Jenkinsfile) — Main pipeline definition
- [GitHub Actions](github-actions.md) — Alternative CI/CD
- [Deployment Strategies](deployment-strategies.md) — Deploy patterns
