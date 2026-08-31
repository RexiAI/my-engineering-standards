# AC-005: Go TDD scaffold

## AC-005-01 — Scaffold directory and Makefile ladder exist
Given the repo after this task
When listing `ci/templates/go-feature/` (or `templates/go-tdd/`)
Then `go.mod` snippet or template exists
And `Makefile` fragment contains targets `ci-fast`, `ci`, `ci-full` with `ci-fast` depending on `vet`/`lint`/`test` per `language-specific/go/SKILL.md`

## AC-005-02 — Test command matches standards
Given the scaffold Makefile
When reading the `test` target
Then it invokes `go test -race -shuffle=on -count=1 ./...`
And `test-cover-html` or `test-cover` is present

## AC-005-03 — Sample tests use stdlib testing and testing/quick
Given the scaffold's sample acceptance test `TestAC_005_01_*`
When inspecting imports
Then it imports `testing` from stdlib and does not import `testify` by default
And a property test imports `testing/quick` (or `pgregory.net/rapid` with a justification comment)

## AC-005-04 — internal/ layout follows Go standards
Given the scaffold
When listing `internal/`
Then it contains `services/`, `store/` (or `repositories/`), and `models/` (or `domain/`)
And `cmd/server/main.go` or `internal/dependency_injection.go` exists for manual DI

## AC-005-05 — Mutation and lint wiring referenced
Given the scaffold README fragment
When reading it
Then it references `gremlins unleash --threshold-efficacy 80` (or `mutation.mk`) and `golangci-lint` with `cyclop`/`gocognit` ≤6
And it does not introduce a DI framework (manual DI only)

## AC-005-06 — Red-then-green loop documented
Given the scaffold README
When following its TDD loop steps
Then it states `go test ./...` fails before implementation and passes after
And property test is noted as `production`-tier (optional at `mvp`)
