# Changelog

## [1.3.1] — 2026-07-28

### Fixes

- **CRLF checkout** — added `.gitattributes` (`*.sh`, `Makefile*`, `*.go` → LF), unset `core.autocrlf`, renormalized repo; all shell scripts were failing `bash -n` due to CRLF line endings
- **Saga gate GitHub/GitLab mismatch** — removed dead `with-saga-gates` input from `init-ci.sh` and `child-ci-*.yml` templates (GitHub Actions has no saga gate job; feature is GitLab-only); fixed `DEPLOYMENT.md`'s false claim; fixed duplicate `backend-ci:` YAML key bug
- **bootstrap.sh → init-ci.sh call** — fixed wrong `--languages` flag and mangled `CI_PLATFORM` string (`githubactions`) that matched no case arm
- **Missing GitLab jobs** — added missing `.java-lint` job (`mvn spotless:check`); fixed `init-ci.sh` `--frontend static` to only emit lint/docker jobs (unit/build are undefined for static)
- **Gate script arg-dropping** — `fail()`/`pass()`/`warn()` in the 4 gate scripts (`check-saga-timeouts.sh`, `check-saga-tests.sh`, `lint-outbox-schema.sh`, `check-outbox-relay.sh`) used `$1`, dropping every arg after the first; remediation guidance never printed. Switched to `$*`
- **check-saga-tests.sh false-PASS** — recovery/persistence check ran outside the `SAGA_TEST_FILES` guard, so an empty file list made `grep -r` default to `.` and false-PASS off an unrelated repo-wide scan; moved inside the guard and changed `grep -r` → `-l` to match its siblings
- **update-submodules.sh subshell bug** — `continue` inside a `( cd $repo; ... )` subshell is a no-op under bash, so repos without a `.standards` submodule (or with one uninitialized) fell through to submodule update/commit; changed to `exit 0`. Also fixed `get_repos`' error message and `exit 1` being swallowed by `$( )` command substitution
- **Non-interactive stdin hangs** — `init-ci.sh`/`bootstrap.sh`'s `collect_secrets()` and the backend/frontend `select` prompts blocked forever on closed/non-tty stdin; guarded all three on `[ -t 0 ]`, defaulting to skip/none. Also fixed `init-ci.sh`'s `[ -n "$FRONTEND" ] && info ...` returning 1 (under `set -e`) on the normal "no frontend" case

## [1.3.0] — 2026-07-12

### Features

- **Saga/Outbox CI quality gates** — `scripts/detect-saga-outbox.sh` (sets `SAGA_DETECTED`/`OUTBOX_DETECTED` from changed files) plus 4 gate scripts: `check-saga-timeouts.sh`, `check-saga-tests.sh`, `lint-outbox-schema.sh`, `check-outbox-relay.sh`
- **ArchUnit rules** — `ci/templates/archunit/SagaArchRules.java` + `ci/templates/archunit/OutboxArchRules.java` (9 structural rules: compensation, `@Transactional`, no direct broker, dedup)
- **Go AST lint** — `ci/templates/go-saga-lint.go` (checks compensation func, `WithTimeout`, no direct broker in saga files)
- **Node ESLint plugin** — `ci/templates/eslint-saga-rules/saga-compensation.js` (`sagaStep()` must declare `compensate` and `timeout`)
- **Integration test templates** — Java/Go/Node × Saga/Outbox under `ci/templates/tests/`
- **init-ci.sh --with-saga** — wires the gates into `ci-java.yml`/`ci-go.yml`/`ci-node.yml` and the child-ci templates
- Updated `docs/SAGA_PATTERN.md`, `docs/OUTBOX_PATTERN.md`, `docs/DEPLOYMENT.md` with CI Quality Gates sections; updated root and language-specific `AGENTS.md` with gate rules

## [1.2.0] — 2026-07-11

### Features

- **Session Hygiene** — `templates/session-start-check.sh` (fail-fast: git clean, lint, tests) and `templates/session-end-check.sh` (full suite, debug artifact scan, Talisman)
- **bootstrap.sh** — auto-copies session hygiene scripts to child projects
- **GIT_WORKFLOW.md** — new "Session Hygiene" section with start/end procedures
- **Makefile.bridge** — `make session-check` / `make session-end` targets

## [1.1.0] — 2026-07-11

### Features

- **OKF (Operational Knowledge Framework) v0.1** — `okf/` directory with 4 linked concept docs for AI-work practices
- **Context Window Policy** — caveman, RTK, headroom, ponytail: how we keep sessions viable 3-5x longer
- **RAG vs Context Stuffing decision** — default to stuffing <50KB, RAG for larger/fresher/semantic queries
- **Detect Context Rot runbook** — 4-metric table + recovery procedure for degrading sessions
- **MCP Server Connection runbook** — pattern + 3 worked examples (GitHub, MyInvestor, Headroom)
- **bootstrap.sh** — now symlinks `okf/` into child repos via `.standards/okf -> okf`
- **opencode.json.bridge** — includes 4 OKF instruction paths

### Refactors

- **bootstrap.sh** — renumbered steps, added OKF symlink, updated next-steps
- **README** — added OKF structure tree + usage section

## [1.0.0] — 2026-07-11

### Features

- **Initial engineering standards** — architecture, testing, deployment, security, and Git workflow
- **12 new architecture docs** — RESILIENCE, IDEMPOTENCY, OBSERVABILITY, SAGA, OUTBOX, SCHEMA_EVOLUTION, CONTRACT_TESTING, EVENTUAL_CONSISTENCY, MESSAGE_DELIVERY, DATA_STORAGE_DECISIONS, SCALABILITY, STREAM_PROCESSING
- **ADR template** — lightweight decision records (`templates/ADR.md`)
- **Composable CI/CD** — orthogonal backend + frontend + shared reusable workflows (GitHub Actions)
- **Frontend CI templates** — Next.js, React (Vite), Angular, Static HTML
- **Shared CI templates** — contract tests (Pact), security scan (CodeQL + Trivy), E2E (Docker Compose)
- **GitLab CI parity** — mirrored structure with backend, frontend, and shared templates
- **No-auto-push and plan-commit rules** — safety guards for agent-based workflows
- **Budget-friendly, vendor-neutral CI/CD** — GHCR default registry, no cloud lock-in

### Refactors

- **Composable CI architecture** — monolithic per-language workflows split into orthogonal backend/frontend/shared jobs
- **Testing standards** — inheritance → composition patterns, in-memory integration tests
- **Vendor references generalized** — company-specific names → generic
- **Express → NestJS** — backend convention switch
- **Correlation ID → Trace ID** — W3C trace context standard
- **Service tests → E2E** — consistent naming

### Chores

- Go 1.20 → 1.26 (LTS)
- Java 17 → 21 (LTS)
- Node.js 18 → 22 (LTS)
- `.serena` removed
- Company-specific and `sss` references cleaned
- golangci.yml: `enable-all` → explicit linter list
- Pact Broker URL moved from input to secret

### Fixes

- Service tests renamed to E2E
- Mutation testing added to validation pipeline

### Notes

- `@main` refs for `uses:` in child workflows
- No lock files committed — child projects manage their own
- Version file: `VERSION` (plaintext, semver)

[1.3.1]: https://github.com/pucelano-95/my-engineering-standards/releases/tag/v1.3.1
[1.3.0]: https://github.com/pucelano-95/my-engineering-standards/releases/tag/v1.3.0
[1.2.0]: https://github.com/pucelano-95/my-engineering-standards/releases/tag/v1.2.0
[1.1.0]: https://github.com/pucelano-95/my-engineering-standards/releases/tag/v1.1.0
[1.0.0]: https://github.com/pucelano-95/my-engineering-standards/releases/tag/v1.0.0
