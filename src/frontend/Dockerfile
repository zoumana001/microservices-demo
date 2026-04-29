# ─────────────────────────────────────────────
# Stage 1 — Build
# ─────────────────────────────────────────────
FROM golang:1.25-alpine AS builder

RUN apk add --no-cache git ca-certificates gcc musl-dev

WORKDIR /app

# Copy the entire frontend source first
# (Online Boutique frontend has its go.mod here)
COPY . .

# Download dependencies
RUN go mod download
 
# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
    -ldflags="-w -s" \
    -o /app/frontend \ 
    .

# ─────────────────────────────────────────────
# Stage 2 — Runtime
# ─────────────────────────────────────────────
FROM gcr.io/distroless/base-debian12:nonroot

COPY --from=builder /app/frontend  /frontend
COPY --from=builder /app/templates /templates
COPY --from=builder /app/static    /static

USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/frontend"]
