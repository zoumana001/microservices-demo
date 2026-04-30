FROM golang:1.25-alpine AS builder

RUN apk add --no-cache git ca-certificates gcc musl-dev

WORKDIR /app

COPY . .

RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o frontend .

# ─────────────────────────────────────────────
# Runtime — use same Go image so paths work
# ─────────────────────────────────────────────
FROM alpine:3.19

RUN apk add --no-cache ca-certificates

WORKDIR /app

# Copy binary
COPY --from=builder /app/frontend .

# Copy templates and static — CRITICAL, must be at /app/templates
COPY --from=builder /app/templates ./templates
COPY --from=builder /app/static    ./static

RUN adduser -D -s /bin/sh appuser
USER appuser

EXPOSE 8080
ENTRYPOINT ["/app/frontend"]