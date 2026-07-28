# Git Workflow Standards

## Branch Naming

Use structured branch names following this pattern:

```
<type>/<short-description>
```

Types:
- `feature/` — new features.
- `fix/` — bug fixes.
- `chore/` — maintenance, dependency updates, tooling.
- `docs/` — documentation changes.
- `refactor/` — code restructuring without behavior change.
- `test/` — adding or fixing tests.

Examples:
- `feature/user-password-recovery`
- `fix/null-pointer-in-session`
- `chore/update-spring-boot-2-7-0`

## Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `chore`, `docs`, `test`, `refactor`, `perf`, `style`, `ci`, `build`, `revert`.

Scope is the service/module/area name (optional but encouraged).

Examples:
```
feat(auth): add OAuth2 JWT bearer grant type
fix(session): handle null session on token refresh
chore: bump company-commons to 0.7.1
```

## Pull Request Workflow

### Before Opening a PR

1. Branch from `main` (or the target base branch).
2. Implement changes in your branch with conventional commits.
3. Run the full test suite: unit tests, integration tests.
4. Run lint/format checkers (Spotless, ESLint, golangci-lint).
5. Update any affected documentation.

### PR Requirements

- Title follows conventional commit format.
- Description explains: what changed, why, how to verify.
- All CI checks pass (build, tests, code quality gates, security scan).
- At least one reviewer approves.
- No unresolved discussion threads.

### PR Title Format

```
<type>(<scope>): <imperative description>
```

### PR Template

```
## What changed
[Summary of changes]

## Why
[Business/technical justification]

## How to verify
[Steps to test or verify the change]
[Link to related E2E tests if applicable]

## Dependencies
[List any PRs, submodule updates, or configuration changes needed]
```

## Review Process

1. Author opens PR and requests reviewers.
2. Reviewers provide feedback via code comments.
3. Author addresses feedback with additional commits.
4. For significant changes, re-request review after addressing feedback.
5. Reviewer approves.
6. Author merges (squash merge preferred for feature branches).
7. Source branch is deleted after merge.

## Submodule Management

### Adding the Standards Submodule

```bash
git submodule add git@github.com:pucelano-95/my-engineering-standards.git .standards
git commit -m "chore: add engineering standards submodule"
```

### Updating the Submodule

```bash
git submodule update --remote .standards
git add .standards
git commit -m "chore: bump engineering standards"
```

### Initializing After Clone

```bash
git submodule update --init --recursive
```

## Architecture Decision Records (ADRs)

Before implementing any significant architectural change, create an ADR. See `templates/ADR.md`.

Required for:
- Adding a new infrastructure dependency (database, cache, message queue)
- Changing the inter-service communication protocol
- Introducing a new technology or framework
- Changing the data model or schema for critical entities
- Service decomposition or consolidation

ADR lifecycle: Proposed → Accepted → Deprecated → Superseded

ADRs are stored in the child repo at `docs/adr/` and committed alongside the code change.

## Session Hygiene

### Before Starting Work

Run the session health check to verify the project is in a healthy state:

```bash
./session-start-check.sh
```

This checks:
1. Git working tree is clean (no uncommitted or stashed changes from prior session)
2. Lint/format passes
3. Unit tests pass
4. Integration tests pass (if configured)

If any check fails, the previous session left the project in an inconsistent state. Fix the failures before writing new code.

### Before Ending a Session

Run the session end check before committing or pushing:

```bash
./session-end-check.sh
```

This checks:
1. Full test suite passes
2. Lint/format passes
3. No debug artifacts (console.log, print, TODO, debugger)
4. Secret scan (Talisman) passes
5. Git state summary (staged/unstaged changes)

### Why

Failing tests at session start means the prior session ended without verifying the project state. This creates a broken baseline for the next session — any new changes compound the existing failures, and the root cause becomes hard to trace.

Session hygiene prevents this by making it a process failure to end a session with failing tests.

### Bootstrap

Session scripts are auto-copied from `.standards/templates/` during `bootstrap.sh`. If you added the submodule manually:

```bash
cp .standards/templates/session-start-check.sh session-start-check.sh
cp .standards/templates/session-end-check.sh session-end-check.sh
chmod +x session-start-check.sh session-end-check.sh
```

## Pre-commit Hooks

Projects must use Talisman pre-commit hook for secret scanning:

```bash
curl https://thoughtworks.github.io/talisman/install.sh | sh
```

The `.talismanrc` file at the project root configures allowed patterns and exclusion rules.
