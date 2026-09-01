# Go TDD Feature Scaffold

Copy `ci/templates/go-feature/` into your project as a starting slice.

```bash
cp -r .standards/ci/templates/go-feature/* .
# then:
go test -race -shuffle=on -count=1 ./...   # red → implement → green
go vet ./...
golangci-lint run ./...   # cyclop/gocognit ≤6
gremlins unleash --threshold-efficacy 80 --tags integration  # mutation (80, production tier)
```

- Layout: `internal/services`, `internal/store`, `internal/models`, `cmd/server/main.go`, `internal/dependency_injection.go` (manual DI, no framework).
- Tests: stdlib `testing` only (no testify default); property test via `testing/quick` (production tier, optional at mvp per docs/CONFORMANCE_TIERS.md).
- Makefile ladder: `ci-fast` (vet/lint/test) → `ci` → `ci-full`; `test` = `go test -race -shuffle=on -count=1 ./...`, `test-cover-html` present.
- Lint: `go vet` + `golangci-lint` cyclop/gocognit ≤6.
