# Go Makefile — copy to your project root and customize
# Targets invoked by CI: test, test-integration, test-contract, lint, build, docker

APP_NAME   ?= $(shell basename $(CURDIR))
VERSION    ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
REGISTRY   ?= ghcr.io
IMAGE      ?= $(REGISTRY)/$(shell git remote get-url origin 2>/dev/null | sed 's/.*\/\([^/]*\)\/\([^/]*\)\.git/\1\/\2/' | tr '[:upper:]' '[:lower:]' || echo "user/$(APP_NAME)")
COMMIT_SHA ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "none")
LDFLAGS    := -s -w -X main.version=$(VERSION) -X main.commit=$(COMMIT_SHA)

.PHONY: test test-integration test-contract lint build docker clean

test:                    # Unit tests with race detection
	go test -race -count=1 ./...

test-integration:        # Integration tests (tag: integration)
	go test -tags=integration -race -count=1 ./...

test-contract:          # Contract tests (Pact provider verification)
	go test -tags=contract -race -count=1 ./...

lint:                    # Lint
	golangci-lint run ./...

build:                   # Build binary
	go build -ldflags="$(LDFLAGS)" -o ./bin/$(APP_NAME) ./cmd/main.go

docker:                  # Docker build (push typically done by CI)
	docker build \
		-t $(IMAGE):$(COMMIT_SHA) \
		-t $(IMAGE):latest \
		--build-arg VERSION=$(VERSION) \
		--build-arg COMMIT_SHA=$(COMMIT_SHA) \
		.

clean:                   # Clean artifacts
	rm -rf ./bin/
	go clean
