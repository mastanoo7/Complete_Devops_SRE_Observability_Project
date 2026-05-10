# ============================================================
# Auth Service — Dockerfile
# Multi-stage Dockerfile for Go Auth Service
# Supports:
#   - Builder stage
#   - Development stage with hot reload (Air)
#   - Production distroless image
# ============================================================

# ============================================================
# ── Builder Stage ───────────────────────────────────────────
# ============================================================

FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install required packages
RUN apk add --no-cache \
    git \
    ca-certificates \
    tzdata \
    build-base

# Copy Go module files
COPY go.mod ./

# Download dependencies
RUN go mod download

# Copy application source
COPY . .

# Optional Git commit/version
ARG GIT_COMMIT=local

# Build statically linked binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=${GIT_COMMIT}" \
    -o auth-service \
    ./main.go


# ============================================================
# ── Development Stage ───────────────────────────────────────
# ============================================================

FROM golang:1.22-alpine AS development

WORKDIR /app

# Install required packages
RUN apk add --no-cache \
    git \
    curl \
    wget \
    build-base \
    ca-certificates

# Install Air (hot reload)
RUN wget -O /usr/local/bin/air \
    https://github.com/air-verse/air/releases/latest/download/air_linux_amd64 && \
    chmod +x /usr/local/bin/air

# Copy Go module files
COPY go.mod ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Expose application port + metrics port
EXPOSE 8081 9090

# Start application with hot reload
CMD ["air", "-c", ".air.toml"]


# ============================================================
# ── Production Stage ────────────────────────────────────────
# ============================================================

FROM gcr.io/distroless/static-debian12:nonroot AS production

WORKDIR /app

# Copy compiled binary
COPY --from=builder /app/auth-service /app/auth-service

# Copy SSL certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Run as non-root user
USER nonroot:nonroot

# Expose service ports
EXPOSE 8081 9090

# Start application
ENTRYPOINT ["/app/auth-service"]