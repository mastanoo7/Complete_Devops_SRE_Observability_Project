# Docker Setup — NexaCommerce

## Overview

This guide covers Docker Desktop/Engine setup and the local Docker Compose workflow used in this repository.

## Install Docker

- Windows/macOS: install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Linux: install Docker Engine and Compose plugin

Verify:

```bash
docker --version
docker compose version
```

## Local Compose Workflow

From repository root:

```bash
# Start full local stack
make dev-up

# View running services
docker compose ps

# Stream logs
docker compose logs -f --tail=100

# Stop stack
make dev-down
```

## Important Notes

- `make dev-up` uses both `docker-compose.yml` and `docker-compose.override.yml`.
- If ports are occupied, update local overrides in `docker-compose.override.yml`.
- For first boot, allow extra time for Kafka and database services.

## Health Checks

```bash
curl http://localhost:3000
curl http://localhost:8080/health/live
curl http://localhost:8081/health/live
curl http://localhost:8082/actuator/health
```

