# CI/CD Standards

## Trunk-Based Development Flow

The CI pipeline adapts to the trigger. Each stage is independently executable.

| Trigger | Jobs | Purpose |
|---------|------|---------|
| Push to feature branch | `unit-test` → `lint` | Fast feedback, <5 min |
| Pull request | `unit-test` → `lint` → `contract-test` → `integration-test` | Quality gate before merge |
| Merge to `main` | All of above + `deploy` → `docker` | Ship it |
| Weekly schedule | `smoke-test` → `contract-verification` → `e2e` | Full E2E on staging |

## Language Support

### Go (Makefile-based)

| Step | Make Target | When |
|------|-------------|------|
| `unit-test` | `make test` | Every push |
| `lint` | `make lint` | Every push |
| `contract-test` | `make test-contract` | PR only (Pact) |
| `integration-test` | `make test-integration` | PR only |
| `deploy` | `make build` | Merge to main |
| `docker` | `make docker` | Merge to main |

### Java (Maven)

| Step | Command | When |
|------|---------|------|
| `unit-test` | `mvn test -B` | Every push |
| `lint` | `mvn spotless:check` | Every push |
| `contract-test` | `mvn pact:verify` | PR only (Pact) |
| `integration-test` | `mvn verify -B -DskipITs=false` | PR only |
| `sonar` | `mvn sonar:sonar` | Optional, PR only |
| `deploy` | `mvn clean deploy -DskipTests` | Merge to main |
| `docker` | Docker build & push to GHCR | Merge to main |

Checkstyle config exists at `language-specific/java/checkstyle.xml` but is optional/manual — it is not a CI-enforced gate. Spotless (`spotless:check`) is the enforced Java formatter/lint check. See docs/TESTING.md §Static Analysis for the full tool table.

### Node.js (NestJS — backend)

| Step | Command | When |
|------|---------|------|
| `unit-test` | `npm test -- --passWithNoTests` | Every push |
| `lint` | `npm run lint && npm run format:check` | Every push |
| `contract-test` | `npm run test:pact` | PR only (Pact) |
| `integration-test` | `npm run test:integration` | PR only |
| `deploy` | `npm publish` | Merge to main |
| `docker` | Docker build & push to GHCR | Merge to main |

## Architecture

### Composable Parent-Child Model

The standards repo provides orthogonal backend, frontend, and shared reusable workflows. Child repos compose them with multiple `uses:` jobs in a single `ci.yml`:

```
my-engineering-standards/                    ← Parent (this repo)
├── .github/workflows/
│   ├── backend/
│   │   ├── ci-java.yml                     ← Reusable: Java (mvn)
│   │   ├── ci-go.yml                       ← Reusable: Go (make)
│   │   └── ci-node.yml                     ← Reusable: Node.js backend (npm)
│   ├── frontend/
│   │   ├── ci-nextjs.yml                   ← Reusable: Next.js
│   │   ├── ci-react.yml                    ← Reusable: React (Vite)
│   │   ├── ci-angular.yml                  ← Reusable: Angular
│   │   └── ci-static.yml                   ← Reusable: static HTML
│   └── shared/
│       ├── ci-dependabot.yml               ← Auto-merge patches
│       ├── ci-e2e-weekly.yml               ← Weekly E2E smoke tests
│       ├── ci-release.yml                  ← Semantic Release
│       ├── ci-contract.yml                 ← Pact contract tests
│       ├── ci-security.yml                 ← SAST/SCA scans
│       └── ci-e2e.yml                      ← Full E2E pipeline
├── ci/
│   ├── parent.yml                          ← Shared variables reference
│   ├── gitlab/                             ← GitLab CI templates
│   │   ├── gitlab-ci.yml                   ← Parent GitLab template
│   │   ├── backend/
│   │   │   ├── ci-java.yml
│   │   │   ├── ci-go.yml
│   │   │   └── ci-node.yml
│   │   └── shared/
│   │       ├── ci-dependabot.yml
│   │       ├── ci-e2e-weekly.yml
│   │       └── ci-release.yml
│   ├── templates/                          ← Templates for generation
│   │   ├── Makefile.go
│   │   ├── child-ci-*.yml
│   │   ├── pact-*.yml
│   │   ├── dependabot.yml
│   │   └── releaserc.json
├── scripts/
│   ├── bootstrap.sh                        ← Full project init
│   └── init-ci.sh                          ← CI/CD generator
└── docs/
    └── CI_CD.md

your-project/                                ← Child repo (e.g. monorepo with api + web)
├── .github/workflows/ci.yml                ← Generated: composes backend + frontend jobs
├── .github/dependabot.yml                  ← Generated
├── .releaserc.json                         ← Generated (Node only)
├── Makefile                                ← Generated (Go only)
└── .standards/                             ← Git submodule
```

### GitHub Actions: Child composes Parent

The child's `ci.yml` calls orthogonal reusable workflows — one per layer:

```yaml
jobs:
  # ── Backend CI ──
  backend-ci:
    uses: RexiAI/my-engineering-standards/.github/workflows/backend/ci-go.yml@main
    with:
      go-version-file: go.mod
      docker-registry: ghcr.io
    secrets:
      GHCR_TOKEN: ${{ secrets.GHCR_TOKEN }}

  # ── Frontend CI ──
  frontend-ci:
    uses: RexiAI/my-engineering-standards/.github/workflows/frontend/ci-nextjs.yml@main
    with:
      node-version-file: .nvmrc
    secrets:
      GHCR_TOKEN: ${{ secrets.GHCR_TOKEN }}

  # ── Shared: Release (runs on main merge) ──
  release:
    needs: [backend-ci, frontend-ci]
    if: github.ref_name == github.event.repository.default_branch
    uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-release.yml@main
    secrets:
      GH_TOKEN: ${{ secrets.GH_TOKEN }}

  # ── Shared: E2E (weekly schedule) ──
  e2e:
    if: github.event_name == 'schedule'
    uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-e2e-weekly.yml@main
    with:
      target-url: https://staging.example.com
```

## Toolchain Versions

**Never hardcode a language runtime version in more than one place.** The version manifest a language's own tooling already reads (`go.mod`, `.nvmrc`, `.java-version`, `.python-version`) is the single source of truth. CI, Dockerfiles, and reusable workflow inputs all resolve from it — none of them declare a version independently.

| Lang | Manifest | GitHub input | Setup action |
|---|---|---|---|
| Go | `go.mod` (`go` line, plus `toolchain` if pinning a specific patch) | `go-version-file: go.mod` | `actions/setup-go` reads it natively |
| Node | `.nvmrc` | `node-version-file: .nvmrc` | `actions/setup-node` reads it natively |
| Python | `.python-version` | `python-version-file: .python-version` | `actions/setup-python` reads it natively |
| Java | `.java-version` (plain text, e.g. `21`) | `java-version-file: .java-version` | `actions/setup-java` has **no** native version-file input — `ci-java.yml`'s `resolve-version` job reads the file itself and feeds the resolved value to every other job via job outputs |

`backend/ci-{go,node,java}.yml` and `frontend/ci-{nextjs,react,angular}.yml` all default their `<lang>-version` input to the value that was hardcoded before v1.5.0 (`"1.26"`/`"22"`/`"21"`) for consumers who haven't adopted a manifest file yet. If a consumer sets `<lang>-version-file`, that always takes priority. New consumers should always set the version-file input and skip `<lang>-version` entirely — see the composed `ci.yml` example above.

Dockerfile templates (`templates/Dockerfile.{go,node,next}`) take the same version as a `ARG GO_VERSION=1.26` / `ARG NODE_VERSION=22` build-time default, overridable with `--build-arg` from the same manifest (`--build-arg GO_VERSION=$(go list -m -f '{{.GoVersion}}')`, `--build-arg NODE_VERSION=$(cat .nvmrc)`).

`GOTOOLCHAIN=auto` (Go's own default since 1.21) means a Go 1.22 CI runner will silently download and run whatever version `go.mod`'s `go` or `toolchain` line declares — bumping the manifest is enough, no runner image change needed. `pyenv`/`nvm`/`asdf` behave the same way for their languages when their respective version-file is present.

**Reproducibility vs. freshness are separate problems.** Pin in the manifest for reproducibility — never `GOTOOLCHAIN=latest`, never `FROM golang:latest`, both make `git bisect` and rebuilds non-deterministic. `.github/workflows/shared/ci-toolchain-bump.yml` handles freshness: a weekly reusable workflow that queries each ecosystem's official release feed (go.dev, nodejs.org, actions/python-versions), rewrites the manifest file if a newer version exists, and opens a PR so CI validates the bump before merge — the same pattern Dependabot uses for libraries, applied to the runtime itself. Wire it into a consumer with:

```yaml
# .github/workflows/toolchain-bump.yml
on:
  schedule:
    - cron: '0 6 * * 1'   # weekly, Monday 06:00 UTC
  workflow_dispatch: {}
jobs:
  bump:
    uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-toolchain-bump.yml@main
```

It skips any manifest that doesn't exist in the consumer repo — safe to add even if you only use one of Go/Node/Python.

### GitLab CI: Child includes Parent (composable)

```yaml
include:
  - local: .standards/ci/gitlab/gitlab-ci.yml
  - local: .standards/ci/gitlab/backend/ci-go.yml
  - local: .standards/ci/gitlab/frontend/ci-nextjs.yml
  - local: .standards/ci/gitlab/shared/ci-release.yml

# ── Backend jobs ──
unit-test:
  extends: .go-unit
  stage: test

lint:
  extends: .go-lint
  stage: lint

# ── Frontend jobs ──
frontend-lint:
  extends: .nextjs-lint
  stage: lint

frontend-build:
  extends: .nextjs-build
  stage: deploy
```

## Getting Started

### New Project

```bash
cd your-project

# 1. Add submodule
git submodule add git@github.com:RexiAI/my-engineering-standards.git .standards

# 2. Run bootstrap (detects language, copies configs, prompts for CI)
./.standards/scripts/bootstrap.sh

# 3. Review, commit, push
git add .
git commit -m "chore: add engineering standards submodule"
git push
```

### CI Only (already bootstrapped)

Interactive:

```bash
./.standards/scripts/init-ci.sh
```

Pre-filled (backend-only, e.g. Go API):

```bash
./.standards/scripts/init-ci.sh \
  --platform github \
  --backend go \
  --registry ghcr.io
```

Pre-filled (monorepo, e.g. Go API + Next.js frontend):

```bash
./.standards/scripts/init-ci.sh \
  --platform github \
  --backend go \
  --frontend nextjs \
  --registry ghcr.io
```

### Migration from Legacy Structure

If your child repo uses the old flat paths (`ci-java.yml`, `e2e-weekly.yml`), update your `ci.yml`:

| Old Path | New Path |
|----------|----------|
| `workflows/ci-java.yml` | `workflows/backend/ci-java.yml` |
| `workflows/ci-go.yml` | `workflows/backend/ci-go.yml` |
| `workflows/ci-node.yml` | `workflows/backend/ci-node.yml` |
| `workflows/e2e-weekly.yml` | `workflows/shared/ci-e2e-weekly.yml` |
| `workflows/release.yml` | `workflows/shared/ci-release.yml` |
| `workflows/dependabot.yml` | `workflows/shared/ci-dependabot.yml` |

Steps:
1. Update `uses:` paths in `.github/workflows/ci.yml` to include `backend/`, `frontend/`, or `shared/` prefix
2. Split monolithic `ci-node.yml` into backend (NestJS) + frontend (Next.js/React) jobs
3. Regenerate with `init-ci.sh --platform github --backend node --frontend nextjs`

### Required Secrets

| Secret | Used By |
|--------|---------|
| `GHCR_TOKEN` | Docker image push (all languages) |
| `MAVEN_USERNAME` | GitHub Packages deploy (Java) |
| `MAVEN_PASSWORD` | GitHub Packages deploy (Java) |
| `NPM_TOKEN` | npm publish (Node.js) |
| `SONAR_TOKEN` | SonarQube analysis (optional) |
| `PACT_BROKER_URL` | Contract tests (optional) |

## Weekly E2E Pipeline

*Conformance tier: `production`. See docs/CONFORMANCE_TIERS.md — projects with no staging environment don't need this job; it has nothing to run against.*

Full end-to-end tests run **every Sunday at 2am UTC**.

Your project configures endpoints:

```yaml
# .github/workflows/e2e.yml
name: Weekly E2E
on:
  schedule:
    - cron: '0 2 * * 0'

jobs:
  e2e:
    uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-e2e-weekly.yml@main
    with:
      target-url: https://staging.example.com
      smoke-endpoints: /health,/api/v1/users/me,/api/v1/products
```

## Contract Testing with Pact

*Conformance tier: `multi-service`. See docs/CONFORMANCE_TIERS.md — contract tests verify a boundary between two independently-deployed services. A single-service project has no boundary to verify; `make test-contract` should be left undefined rather than wired to a no-op.*

Contract tests run on every PR, replacing heavy E2E. They verify that service
providers still match consumer expectations without deploying the full stack.

### Quick Start

**Java** — Add to `pom.xml`:
```xml
<plugin>
  <groupId>au.com.dius.pact.provider</groupId>
  <artifactId>maven</artifactId>
  <version>4.6.15</version>
</plugin>
```

**Go** — Add test file `pact_provider_test.go`:
```go
func TestPactProvider(t *testing.T) {
    pact.VerifyProvider(t, types.VerifyRequest{
        Provider: "my-service",
        BrokerURL: os.Getenv("PACT_BROKER_URL"),
    })
}
```

**Node** — Add test file `test/pact/verify.spec.ts`:
```ts
await new Verifier({
  provider: 'my-service',
  pactBrokerUrl: process.env.PACT_BROKER_URL,
}).verifyProvider();
```

See `ci/templates/pact-*.yml` for full examples and local Pact Broker setup.

## Release Process

Releases are fully automated via [Semantic Release](https://semantic-release.gitbook.io/semantic-release/).
**No manual tagging. No `VERSION` file.** The version is derived from conventional commit messages
since the last release, and the git tag is the sole source of truth.

### Trigger

Semantic Release runs automatically after every successful merge to `main`. The release job in
`ci-release.yml` is conditioned on `github.ref_name == github.event.repository.default_branch`
(GitHub) or `$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH` (GitLab).

### Version bump rules

| Commit type | Version bump | Example |
|---|---|---|
| `fix:` | Patch (`0.0.X`) | `fix: handle null pointer in login` |
| `feat:` | Minor (`0.X.0`) | `feat: add password reset flow` |
| `feat!:` or `BREAKING CHANGE:` footer | Major (`X.0.0`) | `feat(api)!: change response format` |
| `chore:`, `docs:`, `test:`, `refactor:`, `ci:` | No release | maintenance — no tag created |

### What Semantic Release does

1. Reads commits since the last `vX.Y.Z` tag on `main`.
2. Computes the next version from commit types above.
3. Creates an annotated git tag `vX.Y.Z` on `main`.
4. Publishes a GitHub/GitLab release with auto-generated changelog.
5. Commits updated `CHANGELOG.md` back to `main` (via `@semantic-release/git`).

### Configuration

Copy `ci/templates/releaserc.json` to `.releaserc.json` in the child repo.
Required secrets: `GH_TOKEN` (GitHub) or a project access token with `write_repository` scope (GitLab).

See `templates/branch-protection.md` for required branch-protection settings that prevent
direct pushes to `main` (a prerequisite for the PR-only trunk workflow).
