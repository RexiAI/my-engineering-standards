# Engineering Standards

This repo contains shared engineering standards used across all projects. It's added as a `.standards/` git submodule in child repos. The `opencode.json` in each child repo points its `instructions` array at files in this submodule.

Before coding in any child repo, read the relevant docs from this submodule. The architecture, testing, deployment, security, coding, and git workflow standards are in `docs/`. Language-specific rules are in `language-specific/<lang>/SKILL.md`.

## General Rules

- Prefer layered architecture: controller → service → repository.
- Business logic belongs in services, never in controllers or repositories.
- Use dependency injection; avoid service locator or static state.
- Handle errors at the boundary (controller advice / middleware), return structured error responses.
- Every service must expose health endpoints (`/health`) that check all external dependencies.
- Log at boundaries of every service method. Use structured logging with trace IDs.
- Never commit secrets, credentials, or tokens. For small projects `.env` files are fine (always in `.gitignore`). For production, use a secrets manager.
- Write tests in layers: unit, acceptance, integration, e2e — see `docs/TESTING.md`. Use mutation testing to validate test quality (`production` tier, see `docs/CONFORMANCE_TIERS.md`).
- Design principles (KISS, DRY, YAGNI, SOLID, cyclomatic ≤6, property tests) are mechanically enforced by `scripts/check-code-principles.sh` — see `docs/CODING_CONVENTIONS.md §Design Principles`. The spec pipeline's Verifier runs it as an independent gate; run it standalone via the `check-principles` skill any time you want a design audit. A FAIL is a defect; a WARN is a review hint.
- Orchestration wiring is mechanically checked by `scripts/check-orchestration.sh` — every `agent:`/`agent_type=`/backtick agent reference resolves to a real file under `agents/`, every skill cited in `agents/*.md` resolves under `skills/<name>/SKILL.md`, every `scripts/...` path cited in `agents/`, `commands/`, and `AGENTS.md` resolves (a `.sh`/`.ps1` twin counts), and every `docs/[A-Z_]+.md` / `language-specific/<lang>/SKILL.md` reference in `agents/*.md` resolves. Exit 0 = all orchestration references resolve; exit 1 = at least one broken reference.
- Agent and skill standards (Agent Skills spec + Anthropic design principles) are mechanically checked by `scripts/check-skills.sh` — see `docs/AGENTS_AND_SKILLS.md`. Every `skills/*/SKILL.md` and `language-specific/*/SKILL.md` is validated for frontmatter compliance, name-directory matching, line limits, and reference structure. Exit 0 = all skills compliant.
- Use conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`.
- Never commit or push changes unless the user explicitly instructs it. Commits and pushes require manual confirmation. **Exception**: the spec pipeline's PR Opener stage (`agents/spec-pr-opener.md`) may commit, push, and open a draft PR unattended, but only on a `spec/NNN-slug` branch and only after every configured quality gate is green (including a green Mutation Runner report) — see `docs/SPEC_PIPELINE.md §Commit and push carve-out`. The Mutation Runner (`agents/spec-mutation-runner.md`) never commits or pushes. No other agent or workflow gets this exception.
- **All changes reach `main` via pull request. Direct push to `main` or `master` is forbidden — for humans and agents alike, with no exceptions.** This applies to this repo and every child repo. See `docs/GIT_WORKFLOW.md §Strategy: Trunk-Based Development` and `templates/branch-protection.md`.
- **Never create git version tags.** Tags are created automatically by CI (Semantic Release) after a PR merges to `main`. See `docs/GIT_WORKFLOW.md §Versioning` and `docs/CI_CD.md §Release Process`.
- In plan mode, every plan must state whether the agent should auto-commit after completing the work or wait for user confirmation.
- Loops never skip L1 (report) on a production repo — see `docs/LOOP_ENGINEERING.md §Readiness levels`.
- Verify agent-delivered work against the live system before calling it done — a diff that compiles and a diff that works are different claims. For an API change, that means actually calling the endpoint (curl, a test client, whatever's fastest) and checking the response, not just reading the code and reasoning that it should work. Field-name mismatches, wrong status codes, and auth-header mistakes are exactly the class of bug that "looks right" in a diff and fails on the first real request.
- Every language guide lives at `language-specific/<lang>/SKILL.md` as a small entry point — project shape, always-rules, and pointers to the rest. Keep that file small; deep material lives in sibling files in the same directory (e.g. `PATTERNS.md`, `NATIVE.md`, `TESTING.md`). The index links to siblings; it does not embed them.

## Language Selection

This project structure supports Java, Go, JavaScript/TypeScript, and React Native. Before writing code, read the language-specific `SKILL.md` in `language-specific/<lang>/` for conventions relevant to that stack.

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
- Read `docs/LOOP_ENGINEERING.md` before designing or running a loop (an automated agent cycle with durable state).
- Read `docs/AGENTS_AND_SKILLS.md` before creating or modifying any agent in `agents/` or skill in `skills/`/`language-specific/`.
- Read `docs/GOVERNANCE.md` before changing pipeline roles, the gate catalog, or billing constraints — trust tiers, model-assignment discipline, and the ADR requirement live there.

## OpenCode Go Model Configuration

This repo's spec pipeline agents are configured to use OpenCode Go subscription models via `opencode.json` `{env:SPEC_*_MODEL}` references:

| Agent | Primary Model | Fallback Chain (via `@smart-coders-hq/opencode-model-fallback` plugin) |
|---|---|---|
| spec-specifier | `opencode-go/deepseek-v4-flash` | `glm-5.2` → `kimi-k2.7-code` |
| spec-ux | `opencode-go/deepseek-v4-flash` | `glm-5.2` → `kimi-k2.7-code` |
| spec-verifier | `opencode-go/qwen3.7-plus` | `glm-5.2` → `kimi-k2.7-code` |
| spec-mutation-runner | `opencode-go/qwen3.7-plus` | `glm-5.2` → `kimi-k2.7-code` |
| spec-pr-opener | `opencode-go/qwen3.7-plus` | `glm-5.2` → `kimi-k2.7-code` |
| spec-coder | `opencode-go/deepseek-v4-flash` | `kimi-k2.7-code` → `glm-5.1` |
| spec-refactorer | `opencode-go/deepseek-v4-flash` | `kimi-k2.7-code` → `glm-5.1` |
| spec-pipeline | `opencode-go/deepseek-v4-flash` | `kimi-k2.7-code` → `glm-5.1` |

Per-machine values arrive via the gitignored repo-root `.envrc` (direnv). It
loads the committed `config/model.local.env.example` defaults, then the
gitignored `config/model.local.env` override, then the gitignored
`config/agent.local.env` credentials — each via a `dotenv_if_exists` line
(later lines win; a dotenv line clobbers any pre-existing value). One-time
setup per machine: copy `templates/.envrc.example` to `.envrc`, run
`direnv allow`, and (only to override a default) copy
`config/model.local.env.example` to `config/model.local.env`. Switching a
model means editing `config/model.local.env` and restarting opencode — **no
commit, no PR**.
`scripts/check-model-env.sh` enforces structurally that `opencode.json` keeps no
literal model id and neither real env file is ever tracked; self-ci additionally
downloads a pinned opencode binary and runs `scripts/model-env.runtime-check.sh`
to verify the resolution behavior. See `docs/SPEC_PIPELINE.md §Model
configuration` for the full mechanism and precedence.

**Plugin triggers**: `rate_limit`, `quota_exceeded`, `5xx`, `timeout`, `overloaded`. Cooldown: 5 min; retry original after 15 min; max depth: 3.

**Provider fallback**: OpenCode Go falls back to Zen balance if "Use balance" is enabled in console. Otherwise requests error → plugin catches and switches model.

To replicate on another machine: configure the same per-agent entries in `~/.config/opencode/model-fallback.json` (see plugin docs).

## Per-machine agent environment (credentials)

Pipeline agents consume two GitHub credentials per machine — neither is ever
committed:

- `GITHUB_TOKEN` — GitHub MCP server auth (`okf/mcp-server-connection.md`) and
  PR diagnostic comments (`docs/TESTING.md`); fine-grained PAT with `repo` scope.
- `GH_TOKEN` — `gh` CLI / release automation (`docs/CI_CD.md` §Release Process);
  the spec PR Opener uses it when pushing the spec branch and opening the draft PR.

One-time setup per machine:

```bash
cp config/agent.local.env.example config/agent.local.env   # committed template → gitignored real file
# edit config/agent.local.env — fill in the real values
cp templates/.envrc.example .envrc                         # per-machine .envrc, gitignored
direnv allow                                               # load the .envrc at the repo root
```

The repo-root `.envrc` is direnv's per-directory source of truth: its
`dotenv_if_exists` lines load the committed model defaults, the per-machine
override, then `config/agent.local.env` — so the shell where `/spec` and
`/build` run (and every shell spawned from it) sees the credentials. A dotenv
line clobbers pre-existing exported variables; later lines win.

**Never commit `config/agent.local.env`.** That rule is structural, not
advisory: `.gitignore` covers it, `scripts/guard-env.sh` refuses to commit it
(self-ci + the file child repos wire into `.githooks/pre-commit` per
`docs/GIT_WORKFLOW.md` §Git Hooks), and `scripts/check-no-hardcoded-secrets.sh`
scans `agents/`, `commands/`, `scripts/`, `docs/` for literal credential values
on every push/PR.

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
