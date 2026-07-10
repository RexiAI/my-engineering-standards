# Engineering Standards

This repo contains shared engineering standards used across all projects. It's added as a `.standards/` git submodule in child repos. The `opencode.json` in each child repo points its `instructions` array at files in this submodule.

Before coding in any child repo, read the relevant docs from this submodule. The architecture, testing, deployment, security, coding, and git workflow standards are in `docs/`. Language-specific rules are in `language-specific/<lang>/AGENTS.md`.

## General Rules

- Prefer layered architecture: controller → service → repository.
- Business logic belongs in services, never in controllers or repositories.
- Use dependency injection; avoid service locator or static state.
- Handle errors at the boundary (controller advice / middleware), return structured error responses.
- Every service must expose health endpoints (`/health`) that check all external dependencies.
- Log at boundaries of every service method. Use structured logging with correlation IDs.
- Never commit secrets, credentials, or tokens. Use a secrets manager (AWS SSM, etc.) for configuration.
- Write tests in three layers: unit (pure logic), integration (with infrastructure), service (end-to-end with Docker compose).
- Use conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`.

## Language Selection

This project structure supports Java, Go, and JavaScript/TypeScript. Before writing code, read the language-specific `AGENTS.md` in `language-specific/<lang>/` for conventions relevant to that stack.

## Reading the Standards

- For features that touch multiple layers, read `docs/ARCHITECTURE.md` before designing.
- For any test file, read `docs/TESTING.md` first for the expected test structure and patterns.
- Read `docs/SECURITY.md` before implementing authentication, authorization, data handling, or configuration loading.
- Read `docs/GIT_WORKFLOW.md` before creating branches, commits, or PRs.
