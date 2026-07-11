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
- Write tests in three layers: unit (pure logic), integration (with infrastructure), e2e (Docker compose, real endpoints). Use mutation testing to validate test quality.
- Use conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`.
- Never commit or push changes unless the user explicitly instructs it. Commits and pushes require manual confirmation.
- In plan mode, every plan must state whether the agent should auto-commit after completing the work or wait for user confirmation.

## Language Selection

This project structure supports Java, Go, and JavaScript/TypeScript. Before writing code, read the language-specific `AGENTS.md` in `language-specific/<lang>/` for conventions relevant to that stack.

## Reading the Standards

- For features that touch multiple layers, read `docs/ARCHITECTURE.md` before designing.
- For any test file, read `docs/TESTING.md` first for the expected test structure and patterns.
- Read `docs/SECURITY.md` before implementing authentication, authorization, data handling, or configuration loading.
- Read `docs/GIT_WORKFLOW.md` before creating branches, commits, or PRs.


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
