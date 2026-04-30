# src/frontend/Dockerfile
FROM golang:1.25-alpine AS builder

RUN apk add --no-cache git ca-certificates gcc musl-dev

WORKDIR /app

COPY . .

RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o /app/frontend .

# ─────────────────────────────────────────────
FROM golang:1.25-alpine

WORKDIR /app

# Copy binary
COPY --from=builder /app/frontend .

# Copy templates and static files — these MUST exist at runtime
COPY --from=builder /app/templates ./templates
COPY --from=builder /app/static    ./static

USER nobody
EXPOSE 8080
ENTRYPOINT ["/app/frontend"]