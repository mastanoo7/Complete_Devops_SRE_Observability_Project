# ============================================================
# Auth Service Dockerfile
# ============================================================

# ============================================================
# Builder Stage
# ============================================================

FROM golang:1.22-alpine AS builder

WORKDIR /app

RUN apk add --no-cache \
    git \
    ca-certificates \
    tzdata \
    build-base

COPY . .

RUN go mod tidy

ARG GIT_COMMIT=local

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=${GIT_COMMIT}" \
    -o auth-service \
    ./main.go


# ============================================================
# Development Stage
# ============================================================

FROM golang:1.22-alpine AS development

WORKDIR /app

RUN apk add --no-cache \
    git \
    ca-certificates \
    build-base

COPY . .

RUN go mod tidy

EXPOSE 8081 9090

CMD ["go", "run", "main.go"]


# ============================================================
# Production Stage
# ============================================================

FROM gcr.io/distroless/static-debian12:nonroot AS production

WORKDIR /app

COPY --from=builder /app/auth-service /app/auth-service

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

USER nonroot:nonroot

EXPOSE 8081 9090

ENTRYPOINT ["/app/auth-service"]