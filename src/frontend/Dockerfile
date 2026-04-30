FROM golang:1.25-alpine AS builder
RUN apk add --no-cache git ca-certificates gcc musl-dev
WORKDIR /app
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \ 
    go build -ldflags="-w -s" -o frontend .

FROM alpine:3.19
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=builder /app/frontend .
COPY --from=builder /app/templates ./templates
COPY --from=builder /app/static    ./static
RUN adduser -D -s /bin/sh appuser
USER appuser
EXPOSE 8080
ENTRYPOINT ["/app/frontend"]
