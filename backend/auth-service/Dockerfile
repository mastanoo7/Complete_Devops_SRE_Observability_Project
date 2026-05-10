# ============================================================
# Auth Service Dockerfile
# ============================================================

# ============================================================
# Builder Stage
# ============================================================

FROM golang:1.22 AS builder

WORKDIR /app

# Copy source code
COPY . .

# Download dependencies
RUN go mod tidy

# Optional version
ARG GIT_COMMIT=local

# Build binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=${GIT_COMMIT}" \
    -o auth-service \
    ./main.go


# ============================================================
# Development Stage
# ============================================================

FROM golang:1.22 AS development

WORKDIR /app

# Copy source code
COPY . .

# Download dependencies
RUN go mod tidy

# Expose ports
EXPOSE 8081 9090

# Run application
CMD ["go", "run", "main.go"]


# ============================================================
# Production Stage
# ============================================================

FROM debian:bookworm-slim AS production

WORKDIR /app

# Copy binary
COPY --from=builder /app/auth-service /app/auth-service

# Expose ports
EXPOSE 8081 9090

# Run application
CMD ["/app/auth-service"]