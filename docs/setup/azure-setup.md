# Azure Setup Guide — NexaCommerce

## Overview

Use this guide to configure Azure CLI access and prepare Azure resources used by the platform.

## Prerequisites

```bash
az version
az login
az account show
```

## Select Subscription

```bash
az account set --subscription "<subscription-id-or-name>"
az account show --query "{name:name,id:id,tenantId:tenantId}"
```

## AKS Credentials (Example)

```bash
az aks get-credentials \
  --resource-group nexacommerce-dev-rg \
  --name nexacommerce-dev \
  --overwrite-existing

kubectl get nodes
```

## Related

- [Azure Architecture](../architecture/azure-architecture.md)
- [Kubernetes Setup](kubernetes-setup.md)
- [Terraform Setup](terraform-setup.md)

