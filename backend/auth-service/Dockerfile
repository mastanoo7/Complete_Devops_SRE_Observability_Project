# ============================================================
# Auth Service — Dockerfile
# Multi-stage build for Go service
# ============================================================

# ── Build Stage ───────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install required packages
RUN apk add --no-cache git ca-certificates tzdata

# Copy go mod
COPY go.mod ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Optional build arg
ARG GIT_COMMIT=local

# Build binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=${GIT_COMMIT}" \
    -o auth-service \
    ./main.go


# ── Development Stage ─────────────────────────────────────
FROM golang:1.22-alpine AS development

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git

# Add Go bin to PATH
ENV PATH="/go/bin:${PATH}"

# Install Air
RUN go install github.com/air-verse/air@latest

# Copy go mod
COPY go.mod ./

# Download dependencies
RUN go mod download

# Copy source
COPY . .

# Expose ports
EXPOSE 8081 9090

# Start hot reload
CMD ["air", "-c", ".air.toml"]


# ── Production Stage ──────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot AS production

WORKDIR /app

# Copy binary
COPY --from=builder /app/auth-service /app/auth-service

# Copy SSL certs
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy timezone info
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Non-root user
USER nonroot:nonroot

# Expose ports
EXPOSE 8081 9090

# Start service
ENTRYPOINT ["/app/auth-service"]