# Engineering Standards

This repo contains shared engineering standards used across all projects. It's added as a `.standards/` git submodule in child repos. The `opencode.json` in each child repo points its `instructions` array at files in this submodule.

Before coding in any child repo, read the relevant docs from this submodule. The architecture, testing, deployment, security, coding, and git workflow standards are in `docs/`. Language-specific rules are in `language-specific/<lang>/AGENTS.md`.

## General Rules

- Prefer layered architecture: controller → service → repository.
- Business logic belongs in services, never in controllers or repositories.
- Use dependency injection; avoid service locator or static state.
- Handle errors at the boundary (controller advice / middleware), return structured error responses.
- Every service must expose health endpoints (`/health`) that check all external dependencies.
- Log at boundaries of every service method. Use structured logging with trace IDs.
- Never commit secrets, credentials, or tokens. For small projects `.env` files are fine (always in `.gitignore`). For production, use a secrets manager.
- Write tests in layers: unit, acceptance, integration, e2e — see `docs/TESTING.md`. Use mutation testing to validate test quality (`production` tier, see `docs/CONFORMANCE_TIERS.md`).
- Use conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`.
- Never commit or push changes unless the user explicitly instructs it. Commits and pushes require manual confirmation. **Exception**: the spec pipeline's Architect stage (`agent/architect.md`) may commit, push, and open a draft PR unattended, but only on a `spec/NNN-slug` branch and only after every configured quality gate is green — see `docs/SPEC_PIPELINE.md §Commit and push carve-out`. No other agent or workflow gets this exception.
- In plan mode, every plan must state whether the agent should auto-commit after completing the work or wait for user confirmation.
- Verify agent-delivered work against the live system before calling it done — a diff that compiles and a diff that works are different claims. For an API change, that means actually calling the endpoint (curl, a test client, whatever's fastest) and checking the response, not just reading the code and reasoning that it should work. Field-name mismatches, wrong status codes, and auth-header mistakes are exactly the class of bug that "looks right" in a diff and fails on the first real request.

## Language Selection

This project structure supports Java, Go, and JavaScript/TypeScript. Before writing code, read the language-specific `AGENTS.md` in `language-specific/<lang>/` for conventions relevant to that stack.

## Reading the Standards

- For features that touch multiple layers, read `docs/ARCHITECTURE.md` before designing.
- For any test file, read `docs/TESTING.md` first for the expected test structure and patterns.
- Read `docs/SECURITY.md` before implementing authentication, authorization, data handling, or configuration loading.
- Read `docs/GIT_WORKFLOW.md` before creating branches, commits, or PRs.
- Read `docs/RESILIENCE.md` before implementing retry, circuit breaker, timeout, or bulkhead logic.
- Read `docs/IDEMPOTENCY.md` before implementing any mutating endpoint.
- Read `docs/OBSERVABILITY.md` before implementing logging, metrics, or tracing.
- Read `docs/SAGA_PATTERN.md` and `docs/OUTBOX_PATTERN.md` before designing cross-service workflows.
- Read `docs/SCHEMA_EVOLUTION.md` before designing data models or APIs.
- Read `docs/CONTRACT_TESTING.md` before writing service integration tests.
- Read `docs/SPEC_PIPELINE.md` before running `/spec` or `/build`, or before writing an informal spec under `specs/`.

## CI/CD Quality Gates (Saga & Outbox)

Automated gates enforce Saga and Outbox pattern compliance on every PR. Gates are conditional: `scripts/detect-saga-outbox.sh` sets `SAGA_DETECTED` and `OUTBOX_DETECTED` from changed files; all downstream gates skip when both are false.

**Wire gates into a child repo:** `scripts/init-ci.sh --with-saga`

| Gate | Script / Tool | Checks |
|---|---|---|
| Detection | `scripts/detect-saga-outbox.sh` | Sets `SAGA_DETECTED` / `OUTBOX_DETECTED` |
| Saga timeouts | `scripts/check-saga-timeouts.sh` | Every handler has a timeout annotation or `WithTimeout` |
| Saga tests | `scripts/check-saga-tests.sh` | Integration tests exist with compensation scenarios |
| Outbox schema | `scripts/lint-outbox-schema.sh` | Required columns, partial index on `published_at IS NULL`, cleanup |
| Outbox relay | `scripts/check-outbox-relay.sh` | Relay component and consumer dedup store exist |
| Java ArchUnit | `ci/templates/archunit/SagaArchRules.java` + `ci/templates/archunit/OutboxArchRules.java` | 9 structural rules (compensation, `@Transactional`, no direct broker, dedup) |
| Go AST lint | `ci/templates/go-saga-lint.go` | Compensation func, `WithTimeout`, no direct broker in saga files |
| Node ESLint | `ci/templates/eslint-saga-rules/saga-compensation.js` | `sagaStep()` must declare `compensate` and `timeout` |

- Read `docs/SAGA_PATTERN.md §CI Quality Gates` and `docs/OUTBOX_PATTERN.md §CI Quality Gates` before modifying gate scripts or adding saga/outbox code.
- Integration test templates: `ci/templates/tests/` (Java, Go, Node × Saga, Outbox).
- CI job definitions: `ci/gitlab/backend/ci-{java,go,node}.yml` (`.{lang}-saga-gates` hidden jobs).


<!-- headroom:rtk-instructions -->
# RTK (Rust Token Killer) - Token-Optimized Commands

When running shell commands, **always prefix with `rtk`**. This reduces context
usage by 60-90% with zero behavior change. If rtk has no filter for a command,
it passes through unchanged — so it is always safe to use.

## Key Commands
```bash
# Git (59-80% savings)
rtk git status          rtk git diff            rtk git log

# Files & Search (60-75% savings)
rtk ls <path>           rtk read <file>         rtk grep <pattern>
rtk find <pattern>      rtk diff <file>

# Test (90-99% savings) — shows failures only
rtk pytest tests/       rtk cargo test          rtk test <cmd>

# Build & Lint (80-90% savings) — shows errors only
rtk tsc                 rtk lint                rtk cargo build
rtk prettier --check    rtk mypy                rtk ruff check

# Analysis (70-90% savings)
rtk err <cmd>           rtk log <file>          rtk json <file>
rtk summary <cmd>       rtk deps                rtk env

# GitHub (26-87% savings)
rtk gh pr view <n>      rtk gh run list         rtk gh issue list

# Infrastructure (85% savings)
rtk docker ps           rtk kubectl get         rtk docker logs <c>

# Package managers (70-90% savings)
rtk pip list            rtk pnpm install        rtk npm run <script>
```

## Rules
- In command chains, prefix each segment: `rtk git add . && rtk git commit -m "msg"`
- For debugging, use raw command without rtk prefix
- `rtk proxy <cmd>` runs command without filtering but tracks usage
<!-- /headroom:rtk-instructions -->
