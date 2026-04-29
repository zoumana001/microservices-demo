# ─────────────────────────────────────────────
# Dockerfile — Online Boutique frontend (Go)
# Place this at: src/frontend/Dockerfile
# It REPLACES Google's original Dockerfile.
# ─────────────────────────────────────────────

# Stage 1 — Build
# Use the official Go image to compile the binary.
# This stage is thrown away after build — it never
# ends up in the final image.
FROM golang:1.22-alpine AS builder

# Install git (needed for go mod download)
RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copy dependency files first — Docker caches this
# layer and skips re-downloading if go.mod/go.sum
# haven't changed. Big speed win on subsequent builds.
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source code
COPY . .

# Build a statically linked binary
# CGO_ENABLED=0  — no C library dependency
# -w -s          — strip debug info (smaller binary)
# GOOS=linux     — target OS
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
    -ldflags="-w -s" \
    -o /app/frontend \
    ./main.go

# ─────────────────────────────────────────────
# Stage 2 — Runtime
# distroless has NO shell, NO package manager,
# NO OS tools. Trivy finds near-zero CVEs here.
# This is your talking point for the LinkedIn post.
# ─────────────────────────────────────────────
FROM gcr.io/distroless/base-debian12:nonroot

# Copy ONLY the compiled binary from stage 1
COPY --from=builder /app/frontend /frontend

# Copy static assets (templates, images, CSS)
# The frontend serves these at runtime
COPY --from=builder /app/templates /templates
COPY --from=builder /app/static    /static

# nonroot = uid 65532 — never run as root
USER 65532:65532

# Port the frontend listens on
EXPOSE 8080

# Health check — used by Kubernetes liveness probe
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD ["/frontend", "-health_check"]

ENTRYPOINT ["/frontend"]
