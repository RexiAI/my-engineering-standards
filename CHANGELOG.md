# Changelog

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

[1.1.0]: https://github.com/pucelano-95/my-engineering-standards/releases/tag/v1.1.0
[1.0.0]: https://github.com/pucelano-95/my-engineering-standards/releases/tag/v1.0.0
