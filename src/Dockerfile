# --- Build Stage ---
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy dependency manifests and download deps
COPY go.mod go.sum ./
RUN go mod download

# Copy source code and build
COPY app/ ./app/
RUN CGO_ENABLED=0 GOOS=linux go build -o main ./app/main.go

# --- Final Stage ---
FROM alpine:3.19

RUN apk --no-cache add ca-certificates

# Run as a non-root user for production hardening
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

WORKDIR /app
COPY --from=builder /app/main .

EXPOSE 8080

ENV PORT=8080

CMD ["./main"]
