# 001 — TDD Scaffolding (Both Tracks)

> Spec number: 001
> Slug: tdd-scaffolding-both-tracks
> Informal source: `00-informal.md` — "Want scaffold for specific feature (Java/Go/JS) or bootstrap TDD on existing scripts/*.sh via bats/shellspec? both"
> Interpretation: BOTH tracks in one spec.
>   Track A — TDD scaffold for polyglot feature development (Java/Go/JS): templates, helpers, CI wiring so new features start TDD from day 1 per `docs/TESTING.md`.
>   Track B — Bootstrap TDD on existing `scripts/*.sh` via bats/shellspec: retroactively add test harness + initial characterization tests for current shell scripts (`check-code-principles.sh`, `check-*.sh`, `detect-saga-outbox.sh`, etc.).

## Conformance tier
`mvp` (this repo). Mutation and property testing are `production`-tier gates per `docs/CONFORMANCE_TIERS.md` and `docs/SPEC_PIPELINE.md §Conformance tiers`, so the scaffold must include them for child repos that declare `production` but the Verifier in this repo skips them — scaffold is tier-aware, not tier-gated.

---

### Task 001 — Shell TDD harness foundation (Track B infra)

Install and wire a shell test runner for `scripts/*.sh` so characterization tests can run locally and in CI.

**Acceptance criteria**
- [ ] `bats-core` (≥1.10) is the chosen runner; `shellspec` evaluated and rejection documented in 10-tasks open question is resolved or kept as one-line rationale in a comment/README.
- [ ] `scripts/tests/` (or `scripts/tests/bats/`) exists with a shared helper (`test_helper.bash` / `setup.bash`) that sources `scripts/check-common.sh` and `scripts/gate-report-lib.sh` safely.
- [ ] `make test-scripts` (or `make test-shell`) runs all bats tests with `bats --tap` and exits non-zero on any failure; `make ci-fast` depends on or delegates to it.
- [ ] CI (`self-ci.yml` or `validate` job) invokes the harness; a failing bats test fails the job.
- [ ] New file count is bounded: exactly one helper + one Makefile target + at most one workflow line; no per-script harness duplication.
- [ ] `check-no-hardcoded-secrets.sh` still passes after harness addition (no secrets in fixtures).

### Task 002 — Characterization tests for pure gate scripts (Track B — deterministic)

Add initial bats tests for deterministic, side-effect-free gate scripts to lock current behavior before any refactor.

**Scope** — at least three representative scripts from: `detect-saga-outbox.sh`, `check-scenario-traceability.sh`, `check-specs-archived.sh`, `guard-env.sh`, `check-model-env.sh`.
- Each script gets ≥1 bats file with ≥3 scenarios (happy, boundary/empty-input, error/usage).

**Acceptance criteria**
- [ ] Each covered script has a bats file `scripts/tests/<script>.bats` with scenario IDs in test names (e.g. `AC-002-01`).
- [ ] Tests assert exit codes (0/1/2) per the script's documented contract, not internal `grep` counts.
- [ ] Tests assert stdout/stderr fragments that are part of the machine-readable contract (`PASS`/`FAIL`, `exit:`/`command:` patterns where applicable).
- [ ] Empty-input / missing-args / unreadable-dir boundaries are covered and produce exit 2 with an error line (not a silent PASS).
- [ ] Tests run without network, Docker, or repo mutation; they use temp dirs and trap cleanup.
- [ ] Scenario traceability: `scripts/check-scenario-traceability.sh` counts these scenario IDs (or harness is excluded via its own `exclude` if spec tests are intentionally out of scope — documented).

### Task 003 — Characterization tests for complex analysis gate (Track B — check-code-principles)

Add bats tests for the most complex shell gate `check-code-principles.sh` (and at most one more complex gate `check-orchestration.sh` or `check-audit-trail.sh`) to cover the design-principles heuristic.

**Acceptance criteria**
- [ ] `check-code-principles.sh` has a dedicated bats file with ≥5 scenarios covering: complexity >6 FAIL, KISS WARN (>20 lines), DRY duplication WARN, and the `--gates` / `--blocking` / `-ReportPath` flags.
- [ ] At least one scenario drives a real temp source file (Java/Go/JS) through the analyzer and asserts a FAIL line containing file:line evidence.
- [ ] At least one scenario asserts JSON output (`--json` or `-ReportPath`) is valid JSON with `tier`, `gates`, `fails`, `warns` keys.
- [ ] Tier auto-detection (`mvp` vs `production` property-tests gate) is covered: `production` tier without property tests yields FAIL, `mvp` yields skip/PASS — both asserted.
- [ ] Tests complete in <5s total for this task's file (no 1000-file scan); they use minimal fixtures.

### Task 004 — Java TDD scaffold (Track A — Java)

Add a copy-pasteable Java feature scaffold so a new feature starts with a failing acceptance test per `docs/TESTING.md`.

**Acceptance criteria**
- [ ] `ci/templates/java-feature/` (or `templates/java-tdd/`) exists with: `pom-fragment.xml` (JUnit 5 + Mockito + AssertJ + jqwik), `pitest-profile.xml` reference, `src/main/java/...` layered skeleton (controller/service/repository per `docs/ARCHITECTURE.md`), and `src/test/java/...` mirror.
- [ ] A sample acceptance test `*AC_004_01*` demonstrates Given/When/Then naming and `AC-004-NN` traceability, and fails before implementation, passes after (documented in README snippet).
- [ ] `mvn test -Pservice` (or `mvn verify`) wiring described in a one-paragraph README and verified by CI template `ci/templates/child-ci-java.yml` already referencing `test`.
- [ ] Complexity gate wiring (`PMD CyclomaticComplexity ≤6`) mentioned or configured; no custom complexity threshold introduced.
- [ ] No speculative generality: scaffold contains exactly one feature slice, not a full Spring Boot app; no interface-with-one-impl.

### Task 005 — Go TDD scaffold (Track A — Go)

Add a copy-pasteable Go feature scaffold per `language-specific/go/SKILL.md`.

**Acceptance criteria**
- [ ] `ci/templates/go-feature/` (or `templates/go-tdd/`) exists with: `go.mod` snippet, `Makefile` fragment (`ci-fast` → `ci` → `ci-full` ladder, `test` = `go test -race -shuffle=on -count=1 ./...`), and `internal/` layout (`services/`, `store/`, `models/`).
- [ ] A sample acceptance test `TestAC_005_01_*` uses stdlib `testing` only (no `testify` default) and one property test using `testing/quick` (or `pgregory.net/rapid` justified).
- [ ] Gremlins `mutation.mk` reference and threshold 80 documented; `go vet` + `golangci-lint` (`cyclop`/`gocognit` ≤6) referenced.
- [ ] README snippet shows TDD loop: `go test ./...` red → implement → green.
- [ ] No DI framework added; manual DI in `dependency_injection.go` per standards.

### Task 006 — JS/TS TDD scaffold (Track A — JS/TS)

Add a copy-pasteable JS/TS feature scaffold per `language-specific/javascript/SKILL.md` and `docs/TESTING.md`.

**Acceptance criteria**
- [ ] `ci/templates/js-feature/` (or `templates/js-tdd/`) exists with: `package.json` fragment (`vitest` or `jest`, `fast-check`, `stryker` config), `vitest.config.ts` / `jest.config.js`, and `src/modules/<feature>/` + `test/` layout.
- [ ] A sample acceptance test `it("AC-006-01: ...")` plus one `fast-check` property test are present and traceable.
- [ ] `stryker.conf.json` threshold 80 referenced; ESLint `complexity` ≤6 mentioned.
- [ ] Scripts `npm test` and `npx stryker run` are wired and documented; no new package manager introduced.
- [ ] Scaffold supports both `mvp` (mutation skip) and `production` (mutation required) via tier doc link.

### Task 007 — Unified wiring and onboarding guide (Track A+B integration)

Wire both tracks into a single developer entry point and document the TDD start path.

**Acceptance criteria**
- [ ] Root `Makefile` (or existing `Makefile`) exposes `make test` (all tracks), `make test-scripts` (Track B), `make test-java`/`test-go`/`test-js` (Track A templates validated), and `make mutation` / `make property-tests` with tier-aware skip messages.
- [ ] `scripts/bootstrap.sh` and/or `scripts/init-ci.sh` copy or reference the new templates; no hard-coded child path assumptions.
- [ ] `docs/TESTING.md` or `docs/TESTING_TDD_GUIDE.md` short section (≤60 lines) explains: (a) how to start a new feature TDD from scaffold, (b) how to run shell gate tests, (c) how `check-scenario-traceability.sh` enforces AC IDs.
- [ ] `scripts/check-orchestration.sh` passes after wiring (all new agent/skill/script references resolve).
- [ ] End-to-end smoke: a fresh temp dir can bootstrap one Java and one Go feature from templates, run their tests, and get a green/red signal without manual `pom.xml` edits beyond `groupId`.

---

## Open questions — resolved 2026-08-27 (human gate)

1. **Runner choice — bats vs shellspec?** → **Resolved: `bats-core` confirmed.** Use `bats-core ≥1.10` with `bats --tap`. `shellspec` evaluated and rejected; one-line rationale in README/comment.

2. **Scope of Track B initial tests** → **Resolved: 90% coverage of scripts/*.sh.** Not 3–5 representative. `/build` must deliver bats characterization for 90% of `scripts/*.sh` (≥27 of ~30 scripts), each with ≥3 scenarios where applicable. Tasks 002+003 expanded accordingly; a follow-up spec is not acceptable for the remaining 10%.

3. **Where do templates live?** → **Resolved: `ci/templates/<lang>-feature/` confirmed** (stays beside `pitest-profile.xml`, `mutation.mk`, `stryker.conf.json`). Do not use `templates/tdd/<lang>/`.

4. **Child repo tier for templates** → **Resolved: include `production`-tier property/mutation wiring now.** This repo is `mvp` and skips those gates locally, but scaffold must be tier-aware so `production` children are covered from day 1. Confirmed OK.

