# ARG GO_VERSION lets CI or a local build pass --build-arg GO_VERSION=$(go list -m -f '{{.GoVersion}}')
# so the image always matches go.mod instead of drifting from a hardcoded tag here.
ARG GO_VERSION=1.26
FROM golang:${GO_VERSION} AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/service ./cmd/server

FROM alpine:3.18
RUN apk --no-cache add ca-certificates tzdata curl
WORKDIR /app
COPY --from=build /app/service /app/service
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD curl -f http://localhost:8080/health || exit 1
ENTRYPOINT ["/app/service"]
