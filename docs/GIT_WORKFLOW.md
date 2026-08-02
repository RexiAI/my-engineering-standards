# Git Workflow Standards

## Strategy: Trunk-Based Development

This repo and all child repos use **trunk-based development**:

- One long-lived branch: `main`.
- All work happens on short-lived feature branches (target lifetime: < 2 days).
- Feature branches merge to `main` via **squash-merge pull request only**.
- **Direct commits or pushes to `main` (or `master`) are forbidden — for humans and agents, with no exceptions.**
- No long-lived release branches. Tags on `main` mark releases.

Enforce this at the repo level: see `templates/branch-protection.md` for recommended
GitHub and GitLab branch-protection settings.

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
- `spec/NNN-slug` — spec pipeline branches (see `docs/SPEC_PIPELINE.md`).

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

**Commit types determine the next release version** (see §Versioning below). Use
them accurately — `feat:` when adding user-visible behaviour, `fix:` when correcting
it, `chore:`/`docs:`/`test:`/`refactor:` when no release is warranted.

## Versioning (Semver)

All projects follow [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`.

### Rules

| Commit type | Version bump | Example |
|---|---|---|
| `fix:` | Patch (`0.0.X`) | `fix: handle null pointer in login` |
| `feat:` | Minor (`0.X.0`) | `feat: add password reset flow` |
| `feat!:` or `BREAKING CHANGE:` footer | Major (`X.0.0`) | `feat(api)!: change response format` |
| `chore:`, `docs:`, `test:`, `refactor:`, `ci:` | No release | maintenance only |

### Source of truth: git tags only

- **No `VERSION` file.** Git tags are the sole version record.
- Tag format: `vMAJOR.MINOR.PATCH` (e.g. `v1.4.2`).
- Tags are created automatically by CI (Semantic Release) **after** a PR merges to `main`.
- **Never create version tags manually.** Never tag a feature branch.

### Who creates tags

CI creates tags — not humans, not agents. Flow:

```
PR merged to main
       │
       ▼
CI runs Semantic Release
       │
       ├─ reads commit messages since last tag
       ├─ computes next version per the table above
       ├─ creates annotated git tag vX.Y.Z on main
       └─ publishes GitHub/GitLab release with changelog
```

See `docs/CI_CD.md §Release Process` and `ci/templates/releaserc.json`.

## Pull Request Workflow

### Before Opening a PR

1. Branch from `main`.
2. Implement changes in your branch with conventional commits.
3. Run the full test suite: unit tests, integration tests.
4. Run lint/format checkers (Spotless, ESLint, golangci-lint).
5. Update any affected documentation.

### PR Requirements

- Title follows conventional commit format.
- Description explains: what changed, why, how to verify.
- All CI checks pass (build, tests, code quality gates, security scan).
- At least one reviewer approves (`production`+ tier; `mvp` solo projects may self-approve — see `docs/CONFORMANCE_TIERS.md`).
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
6. Author **squash-merges** (squash merge required for all feature branches — disable merge-commit and rebase-merge options in repo settings).
7. Source branch is deleted after merge.

## Submodule Management

### Adding the Standards Submodule

```bash
git submodule add git@github.com:RexiAI/my-engineering-standards.git .standards
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

## Pre-commit Hooks

Projects must use Talisman pre-commit hook for secret scanning:

```bash
curl https://thoughtworks.github.io/talisman/install.sh | sh
```

The `.talismanrc` file at the project root configures allowed patterns and exclusion rules.

## Git Hooks: Local Enforcement

### Install hooks as version-controlled files, not `.git/hooks/`

Point Git at a repo-tracked hooks directory instead of the untracked, unreviewable `.git/hooks/`:

```make
# One-time per clone: wire up local git hooks (.githooks/).
hooks-install:
	git config core.hooksPath .githooks
```

This needs no framework (no husky, no pre-commit.com) — `core.hooksPath` is a native Git feature. Hooks under `.githooks/` are reviewed in PRs like any other code.

### Split by cost: pre-commit is fast, pre-push is thorough

- **pre-commit**: a stated time budget (document it in the file header, e.g. "fast checks only (~5s budget)"), staged-files-only where possible (`git diff --cached --name-only --diff-filter=ACM`, which correctly excludes deletions/renames), skip entirely when no relevant files changed.
- **pre-push**: the full local gate — the same `make ci`/`make test` a human or CI would run, plus anything expensive (E2E) gated by whether the diff actually touches E2E-relevant paths.

### Pre-push: gate on what's being pushed, not the working tree

A naive pre-push hook tests the current working directory, which can differ from what's actually being pushed (uncommitted changes, files the push doesn't include) — producing a false green. Instead, check out the pushed SHA into a detached, ephemeral worktree and run the gate there:

```bash
WT_DIR=$(mktemp -d /tmp/myproject-prepush.XXXXXX)
git worktree add --detach --quiet "$WT_DIR" "$local_sha"
# ... run make ci / make e2e against $WT_DIR ...
git worktree remove --force "$WT_DIR"
```

Register the cleanup as a trap *before* creating the worktree, and use `"${ARR[@]:-}"` expansion for any array under `set -u` so an empty array doesn't trigger an unbound-variable error on early exit.

### Parse the real pre-push protocol correctly

Git invokes pre-push with lines of `local_ref local_sha remote_ref remote_sha` on stdin — three things commonly get this wrong:

```bash
declare -A SEEN
while read -r local_ref local_sha remote_ref remote_sha; do
  [ "$local_sha" = "0000000000000000000000000000000000000000" ] && continue  # ref deletion, nothing to test
  [ -n "${SEEN[$local_sha]:-}" ] && continue                                # dedup: same SHA pushed via multiple refs
  SEEN[$local_sha]=1
  # a new ref has no upstream history to diff against — default to running everything, not skipping it
done
```

### Gate expensive suites on the actual diff, not unconditionally

If a full suite (E2E, a slow integration layer) is too slow to run on every push, gate it on whether the diff between the remote and local SHA touches paths that could break it — and include the CI config and build file themselves in that path pattern, so changing the gate re-runs the gate:

```bash
E2E_PATH_PATTERN='^(\.github/workflows/ci\.yml|scripts/e2e-.*\.sh|cmd/server/|Makefile)'
```

### Escape hatch: an env var, not `--no-verify`

Support skipping hooks via a named environment variable (`SKIP_HOOKS=1 git push`) rather than steering people toward `--no-verify`. An env var is greppable in shell history and CI logs; `--no-verify` silently disables *every* hook class (commit-msg, pre-commit, pre-push) at once, which is usually not what was intended.

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
