# TDD Quick Start (Both Tracks)

## (a) Start a new feature from scaffold

```bash
cp -r .standards/ci/templates/go-feature ./my-feature
# or java-feature / js-feature — edit groupId/artifactId or go.mod module
# Write failing acceptance test first (AC-NNN-NN in name), then implement.
go test -race -shuffle=on -count=1 ./...   # red → green
mvn test -Pservice                          # Java
npm test                                    # JS (vitest run)
```

Scaffolds: `ci/templates/java-feature`, `ci/templates/go-feature`, `ci/templates/js-feature`.
Each contains one slice (controller/service/repository) per docs/ARCHITECTURE.md, no extra abstractions.

## (b) Run shell gate tests (Track B)

```bash
make test-scripts   # bats --tap scripts/tests/*.bats (hermetic, temp dirs)
make ci-fast        # test-scripts + validate-all (no Docker)
```

Harness: `scripts/tests/test_helper.bash` (sources gate-report-lib.sh, check-common.sh, guarded).
Requires bats-core ≥1.10 (see test_helper.bash rationale).

## (c) Scenario traceability

`scripts/check-scenario-traceability.sh [specs] [src]` enforces AC-NNN-NN IDs:
- Every `## AC-NNN-NN` heading in `specs/*/20-acceptance/*.md` must have a test citing `AC-NNN-NN` or `AC_NNN_NN`.
- Every cited ID must resolve to a heading. Exit 1 lists orphans/dangles; exit 2 on tooling/usage error.
Run via `make test` or CI validate job.
