# ============================================================
# Auth Service — Dockerfile
# Multi-stage build for Go service
# ============================================================

# ── Build Stage ───────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install required packages
RUN apk add --no-cache git ca-certificates tzdata

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Optional build arg for versioning
ARG GIT_COMMIT=local

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=${GIT_COMMIT}" \
    -o auth-service \
    ./main.go


# ── Development Stage ─────────────────────────────────────
FROM golang:1.22-alpine AS development

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git

# Add Go binaries to PATH
ENV PATH="/go/bin:${PATH}"

# Install Air for hot reload
RUN go install github.com/air-verse/air@latest

# Copy dependency files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Expose application and metrics ports
EXPOSE 8081 9090

# Start with hot reload
CMD ["air", "-c", ".air.toml"]


# ── Production Stage ──────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot AS production

WORKDIR /app

# Copy compiled binary
COPY --from=builder /app/auth-service /app/auth-service

# Copy SSL certs
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Run as non-root user
USER nonroot:nonroot

# Expose ports
EXPOSE 8081 9090

# Start application
ENTRYPOINT ["/app/auth-service"]