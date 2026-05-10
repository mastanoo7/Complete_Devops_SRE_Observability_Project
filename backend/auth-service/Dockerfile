# ============================================================
# Auth Service — Dockerfile
# Multi-stage build for Go service
# ============================================================

# ── Build Stage ───────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Copy go mod files
COPY go.mod ./
RUN go mod download

# Copy source
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=${GIT_COMMIT}" \
    -o auth-service \
    ./main.go

# ── Development Stage ─────────────────────────────────────
FROM golang:1.22-alpine AS development

WORKDIR /app

RUN apk add --no-cache git

# Install air for hot reload
RUN go install github.com/cosmtrek/air@latest

COPY go.mod ./
RUN go mod download

COPY . .

EXPOSE 8081 9090

CMD ["air", "-c", ".air.toml"]

# ── Production Stage ──────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot AS production

WORKDIR /app

# Copy binary and certs
COPY --from=builder /app/auth-service .
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Run as non-root (distroless nonroot = uid 65532)
USER nonroot:nonroot

EXPOSE 8081 9090

ENTRYPOINT ["/app/auth-service"]
