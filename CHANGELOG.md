# Changelog

## [1.5.0] — 2026-07-28

### Added

- **Conformance tiers** (`docs/CONFORMANCE_TIERS.md`) — `mvp` / `production` / `multi-service`. A project declares its tier once; rules tagged above that tier are out of scope, not a gap. Tagged: Pact contract testing (`multi-service`), mutation testing / ZAP DAST / weekly-E2E-against-staging / SonarQube gate / distributed tracing / full observability / circuit breaker+retry / secrets manager / mandatory-reviewer (`production`).
- **Toolchain version manifests replace hardcoded CI versions (GitHub side; GitLab deferred — no consumer yet)** — `go-version-file`/`node-version-file` inputs added to `backend/ci-{go,node}.yml`, `frontend/ci-{nextjs,react,angular}.yml`; `backend/ci-java.yml` gained a `resolve-version` job since `actions/setup-java` has no native version-file input; `shared/ci-contract.yml` now always resolves from `go.mod`/`.nvmrc`/`.java-version`. Existing hardcoded defaults (`"1.26"`/`"22"`/`"21"`) kept as fallback for consumers without a manifest file yet — only `go-version-file` changes the *default* behavior (every Go module already has a `go.mod`, so this is non-breaking); Node/Java keep opt-in until a consumer adds the manifest file. `templates/Dockerfile.{go,node,next}` gained `ARG GO_VERSION`/`ARG NODE_VERSION` build args instead of hardcoded `FROM` tags. See docs/CI_CD.md §Toolchain Versions.
- **`shared/ci-toolchain-bump.yml`** — new reusable workflow, weekly by default. Queries go.dev/nodejs.org/actions-python-versions for the latest stable/LTS release per manifest present in the consumer repo, rewrites the manifest, opens a PR. Skips any manifest that doesn't exist — safe to add regardless of which languages a consumer uses. The same automation model Dependabot uses for libraries, applied to the runtime itself. Verified end-to-end against live endpoints and against synthetic `go.mod` fixtures (both the plain-`go`-line and `go`+`toolchain`-line cases) before merge.
- **Upstream error responses must not reach the client** (`docs/SECURITY.md`) — a third-party provider's raw error body can leak partial credentials or account details; the existing "mask secrets in logs" rule doesn't cover forwarding the body to your own client.
- **Tri-state quality gate verdicts** (`docs/DEPLOYMENT.md`) — `0 APPROVED` / `1 CONDITIONAL` / `2 REJECTED`, replacing a binary pass/fail that forced every advisory signal to be either dropped or treated as a hard blocker.
- **Stale-compiled-artifact rule** (`docs/DEPLOYMENT.md`) — restarting a container doesn't rebuild the binary inside it; state the rebuild step explicitly wherever a runbook or Makefile target lives.
- **Git Hooks: Local Enforcement** (`docs/GIT_WORKFLOW.md`) — `core.hooksPath` over `.git/hooks/`, pre-commit/pre-push cost split with a stated time budget, pre-push against a detached worktree at the pushed SHA (not the working tree — eliminates dirty-tree false greens), correct pre-push stdin protocol handling (parse the real 4-field lines, skip ref deletions, dedup SHAs, fail-safe on new refs), path-pattern gating for expensive suites, `SKIP_HOOKS=1` over `--no-verify`.
- **E2E practices** (`docs/TESTING.md`) — one script run by both CI and local dev (the only CI/local difference expressible as a single env var), readiness polling instead of fixed sleeps, exit-status-preserving cleanup traps that dump logs only on failure, bounded and justified flake retries. E2E cadence is now tier-gated: `mvp` projects with no staging environment run E2E on every push; `production`+ projects keep it weekly and let contract tests cover PRs.
- **CI failure diagnostics for agent consumers** (`docs/TESTING.md`) — an AI agent driving CI fixes via an API can typically read PR comments but not raw Actions logs; post a byte-bounded, collapsed diagnostic comment on failure instead of leaving it opaque.
- **Comment the why** (`docs/CODING_CONVENTIONS.md`) — a one-line workaround earns a multi-line comment naming the incident or trap it avoids; a comment restating the code below it is noise.
- **Verify agent-delivered work against the live system** (`AGENTS.md`) — a diff that compiles and a diff that works are different claims; field-name mismatches and auth-header mistakes are exactly the class of bug that looks right in a diff and fails on the first real request.

### Changed

- **`log/slog` replaces `zerolog` as the default Go logging library** (`docs/CODING_CONVENTIONS.md`, `language-specific/go/AGENTS.md`) — `slog` has been in the stdlib since Go 1.21, so it's the "prefer stdlib" default rather than an added dependency. Existing zerolog projects don't need to migrate.
- **`cmd/<binary>/main.go` + `internal/` replaces `src/` as the standard Go project layout** (`language-specific/go/AGENTS.md`, `docs/DEPLOYMENT.md`, `templates/Dockerfile.go`) — `internal/` gives compiler-enforced encapsulation a plain `src/` tree can't; `cmd/` is the idiomatic layout for a module producing one or more binaries. `dependency_injection.go` moves under `internal/`.
- **`testify`/`gomock` demoted from default to optional** (`docs/TESTING.md`, `language-specific/go/AGENTS.md`) — the previous blanket "use testify/gomock" guidance contradicted `docs/CODING_CONVENTIONS.md`'s "prefer stdlib, justify each dependency" rule. Stdlib `testing` is now the default; either library remains a fine addition when a project's test complexity justifies it.
- **golangci-lint config absorbed hardening** (`language-specific/go/golangci.yml`) — `max-issues-per-linter: 0` / `max-same-issues: 0` (defaults of 50/3 hide work), `gosec.confidence: low` (widens, doesn't narrows, findings), `gochecknoglobals`/`gochecknoinits` enabled, `gofumpt extra-rules: true`, expanded `_test.go` linter relaxation set (`errcheck`, `gosec`, `gochecknoglobals`, `gochecknoinits` added to the existing `bodyclose`/`noctx`).
- **`make ci-fast` / `make ci` / `make ci-full` gate ladder documented as the standard Go command set** (`language-specific/go/AGENTS.md`) — each rung defined by the infrastructure it needs; CI and git hooks call the same targets instead of duplicating command lists in YAML.
- **`go test -race -shuffle=on -count=1`** is now the documented standard test invocation (`language-specific/go/AGENTS.md`).

## [1.4.1] — 2026-07-28

### Fixed

- **CRLF regression from v1.4.0** — the v1.3.1 "CRLF checkout" fix renormalized this repo while `core.autocrlf=true` was still set globally and `.gitattributes` covered only `*.sh`/`Makefile*`/`*.go`. Every other tracked file (`docs/`, `okf/`, all 13 reusable workflows, ArchUnit `.java`, integration test templates, `prettier.config.js` — which itself declares `endOfLine: 'lf'` — etc.) got committed as CRLF: 84/113 files, verified by inspecting raw committed blobs (v1.3.0 was 0/113). `.gitattributes` now reads `* text=auto eol=lf` first, `*.bat text eol=crlf` added; repo renormalized. Consumers who copied any of those 84 files out of `.standards` between v1.4.0 and this release should re-copy or strip `\r`.
- **Self-CI could not have caught this** — `bash -n` only touches `*.sh`, and PyYAML tolerates CRLF. Added a blob-level CRLF guard job to `self-ci.yml` that inspects `git cat-file blob` directly (bypasses local `core.autocrlf` smudging) so this class of regression fails CI going forward.

## [1.4.0] — 2026-07-28

### Added

- **Self-CI workflow** — `.github/workflows/self-ci.yml` (root-level, so GitHub Actions actually discovers it — the 13 existing workflows are all `workflow_call`-only reusables and never ran on this repo itself). Runs `bash -n` on every shell script, `make validate-all`, `make lint`, advisory `shellcheck`, and a scoped YAML syntax check on push/PR.
- **`templates/Dockerfile.next`** — Next.js standalone-output Dockerfile; the JS AGENTS.md documented ~150 lines of Next.js conventions with no corresponding Dockerfile.

### Fixed

- **Config drift** — `language-specific/javascript/eslint.config.js` rewritten as a real ESLint 9 flat config (was legacy `.eslintrc` schema under a flat-config filename); `language-specific/go/golangci.yml` migrated to v2 schema for Go 1.26 (dropped removed/deprecated linters); `templates/Dockerfile.spring` fixed for its actual Amazon Corretto/AL2023 base (`dnf` not `yum`, `useradd` not Debian `adduser`, `launch.JarLauncher` for Boot 3.2+, `/actuator/health`).
- **Doc contradictions reconciled against real CI** (not guessed) across `docs/MESSAGE_DELIVERY.md`, `docs/OUTBOX_PATTERN.md`, `docs/TESTING.md`, `docs/CI_CD.md`, `docs/DEPLOYMENT.md`, `docs/SECURITY.md`: retry defaults, dedup TTL rationale, E2E cadence, Java lint tool, coverage-gate strictness, artifact publishing target, security tooling table.
- **`templates/` bugs** — `Makefile.bridge`'s success message was tab-indented under the wrong target; its Go branch copied `golangci.yml` under the wrong filename; `init-ai` now copies the session hygiene scripts itself so `session-check`'s own error message is accurate; `session-end-check.sh`'s debug-artifact check now `warn()`s instead of unconditionally `pass()`-ing; `session-start-check.sh` no longer swallows npm lint failures; `PULL_REQUEST_TEMPLATE.md` checklist updated for saga/outbox gates, ADRs, and session-end-check.
- **Saga/outbox gate script precision** — `check-outbox-relay.sh` no longer counts test-file dedup mentions as production dedup; `check-saga-timeouts.sh`'s Go branch scoped from repo-wide to same-file-or-same-directory per handler; `lint-outbox-schema.sh` now isolates the outbox `CREATE TABLE` block before matching required columns instead of matching anywhere in the file; `check-saga-tests.sh`'s compensation-detection regex dropped overly generic alternatives that matched almost any failure-related text.
- **`VERSION`/`CHANGELOG.md` catch-up** and `AGENTS.md`'s stale `Saga+OutboxArchRules.java` reference (the two real files are named separately); `Makefile`'s malformed `help` output and missing `release` in `.PHONY`.

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

[1.4.0]: https://github.com/RexiAI/my-engineering-standards/releases/tag/v1.4.0
[1.3.1]: https://github.com/RexiAI/my-engineering-standards/releases/tag/v1.3.1
[1.3.0]: https://github.com/RexiAI/my-engineering-standards/releases/tag/v1.3.0
[1.2.0]: https://github.com/RexiAI/my-engineering-standards/releases/tag/v1.2.0
[1.1.0]: https://github.com/RexiAI/my-engineering-standards/releases/tag/v1.1.0
[1.0.0]: https://github.com/RexiAI/my-engineering-standards/releases/tag/v1.0.0
