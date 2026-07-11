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

## Pre-commit Hooks

Projects must use Talisman pre-commit hook for secret scanning:

```bash
curl https://thoughtworks.github.io/talisman/install.sh | sh
```

The `.talismanrc` file at the project root configures allowed patterns and exclusion rules.
