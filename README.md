# Engineering Standards

Shared engineering standards for all projects, designed as a Git submodule (`.standards/`) in child repos.

## Usage

```bash
git submodule add git@github.com:RexiAI/my-engineering-standards.git .standards
./.standards/scripts/bootstrap.sh
```

## OKF — Operational Knowledge Framework

[`okf/`](okf/index.md) documents how we work with AI: practices, decisions, and runbooks for managing context windows, choosing between RAG and context stuffing, detecting context rot, and setting up MCP servers.

Child repos inherit OKF via symlink (created by `bootstrap.sh`):

```bash
.standards/okf -> okf
```

OpenCode loads OKF files automatically from `.standards/okf/*.md` via `instructions` in `opencode.json`.

## Structure

```
my-engineering-standards/
├── AGENTS.md                    # Master OpenCode rules
├── docs/
│   ├── ARCHITECTURE.md          # Layered architecture, modules, ADRs
│   ├── CI_CD.md                 # CI/CD pipeline design
│   ├── CODING_CONVENTIONS.md    # Naming, formatting, error handling
│   ├── CONTRACT_TESTING.md      # Pact contract tests
│   ├── DATA_STORAGE_DECISIONS.md# SQL vs NoSQL decision tree
│   ├── DEPLOYMENT.md            # Docker, quality gates
│   ├── EVENTUAL_CONSISTENCY.md  # Consistency model trade-offs
│   ├── GIT_WORKFLOW.md          # Branching, commits, PRs
│   ├── IDEMPOTENCY.md           # Retry-safe endpoints
│   ├── MESSAGE_DELIVERY.md      # Queues, DLQ, reliability
│   ├── OBSERVABILITY.md         # Tracing, metrics, alerting
│   ├── OUTBOX_PATTERN.md        # Reliable event publishing
│   ├── RESILIENCE.md            # Circuit breaker, retry, timeout
│   ├── SAGA_PATTERN.md          # Distributed transaction coordination
│   ├── SCALABILITY.md           # Stateless, caching, load testing
│   ├── SCHEMA_EVOLUTION.md      # Protobuf, versioning, migrations
│   ├── SECURITY.md              # Auth, encryption, scanning
│   ├── STREAM_PROCESSING.md     # Kafka, windows, exactly-once
│   └── TESTING.md               # Three-layer testing strategy
├── language-specific/
│   ├── java/AGENTS.md           # Spring Boot, Maven
│   ├── go/AGENTS.md             # Gin, Makefile
│   └── javascript/AGENTS.md     # NestJS, React
├── okf/                         # Operational Knowledge Framework (AI practices)
│   ├── index.md                 # Root index
│   ├── log.md                   # Changelog
│   ├── context-window-policy.md # Context management (caveman, RTK, headroom)
│   ├── when-to-use-rag.md       # RAG vs context stuffing decision
│   ├── detect-context-rot.md    # Context rot detection runbook
│   └── mcp-server-connection.md # MCP server setup runbook
├── templates/                   # Dockerfiles, gitignores, ADR, PR
├── ci/                          # CI templates & scripts
└── scripts/                     # bootstrap, init-ci
```

## Pinning Versions

```bash
cd .standards && git pull && cd ..
git add .standards && git commit -m "chore: bump engineering standards"
```
