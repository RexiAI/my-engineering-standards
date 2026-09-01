# Go feature Makefile fragment (spec 001)
# Ladder: ci-fast → ci → ci-full per language-specific/go/SKILL.md
# test = go test -race -shuffle=on -count=1 ./... (race + shuffle + no cache)

.PHONY: test test-cover-html vet lint ci-fast ci ci-full build

test:
	go test -race -shuffle=on -count=1 ./...

test-cover-html:
	go test -race -shuffle=on -count=1 -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

vet:
	go vet ./...

lint:
	golangci-lint run ./... # cyclop/gocognit ≤6

ci-fast: vet lint test

ci: ci-fast build

ci-full: ci
	@echo "ci-full: add Docker E2E when needed"

build:
	go build -o bin/app ./cmd/server

mutation:
	@command -v gremlins >/dev/null 2>&1 || { echo "gremlins not found. Install: go install github.com/go-gremlins/gremlins/cmd/gremlins@latest"; exit 1; }
	gremlins unleash --threshold-efficacy 80 --tags integration
