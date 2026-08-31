# AC-007: Unified wiring and onboarding guide

## AC-007-01 — Root Makefile exposes unified targets
Given the repo after this task
When inspecting the root Makefile (or top-level `Makefile`)
Then target `test` exists and depends on `test-scripts` plus docs for lang scaffolds
And targets `test-scripts`, `mutation` (or `test-mutation`), and `property-tests` exist with `--help` or comments showing tier-aware skip: `mvp` prints `skipped — production tier required`

## AC-007-02 — bootstrap and init-ci reference the new templates
Given `scripts/bootstrap.sh` and `scripts/init-ci.sh`
When searching for `java-feature`/`go-feature`/`js-feature` (or chosen prefix `templates/`)
Then at least one of those scripts copies or references the new `ci/templates/*-feature` dirs
And no hard-coded child repo path assumes `/home/` or a specific org name

## AC-007-03 — Onboarding guide is concise and covers both tracks
Given `docs/TESTING.md` (or new `docs/TESTING_TDD_GUIDE.md`) after this task
When counting lines of the new TDD guide section
Then it is ≤60 lines
And it contains three headings or paragraphs covering: (a) starting a new feature TDD from scaffold, (b) running `make test-scripts`, (c) how `check-scenario-traceability.sh` enforces `AC-NNN-NN` IDs

## AC-007-04 — Orchestration check still passes
Given the repo after wiring
When `scripts/check-orchestration.sh` is run
Then it exits 0
And every new `agent:`/`skill`/`scripts/` reference introduced by this spec resolves

## AC-007-05 — Smoke: bootstrap Java and Go features from templates in a temp dir
Given an empty temp dir
When the bootstrap snippet from the guide is run to scaffold one Java feature and one Go feature
Then `mvn test` (or fragment check) and `go test ./...` each produce a green/red signal without manual `pom.xml` edits beyond `groupId`/`artifactId`
And the sample `AC-00N-01` test names are visible in the test output

## AC-007-06 — Existing gates still green
Given the repo after this task
When `scripts/check-code-principles.sh` and `scripts/check-scenario-traceability.sh` are run
Then both exit 0 (or WARN-only) on the changed files
And no new file exceeds 500 lines or method exceeds 20 lines by heuristic
