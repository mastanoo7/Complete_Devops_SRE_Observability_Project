# GCP Setup Guide — NexaCommerce

## Overview

Use this guide to configure Google Cloud CLI access and connect to GKE clusters.

## Prerequisites

```bash
gcloud --version
gcloud auth login
gcloud config set project <project-id>
gcloud auth application-default login
```

## Configure Project and Region

```bash
gcloud config set project <project-id>
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a
```

## GKE Credentials (Example)

```bash
gcloud container clusters get-credentials nexacommerce-dev \
  --region us-central1 \
  --project <project-id>

kubectl get nodes
```

## Related

- [GCP Architecture](../architecture/gcp-architecture.md)
- [Kubernetes Setup](kubernetes-setup.md)
- [Terraform Setup](terraform-setup.md)

