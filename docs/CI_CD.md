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
      go-version: "1.26"
      docker-registry: ghcr.io
    secrets:
      GHCR_TOKEN: ${{ secrets.GHCR_TOKEN }}

  # ── Frontend CI ──
  frontend-ci:
    uses: RexiAI/my-engineering-standards/.github/workflows/frontend/ci-nextjs.yml@main
    with:
      node-version: "22"
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

Uses Semantic Release with conventional commits:

| Commit Type | Release | Example |
|------------|---------|---------|
| `fix:` | Patch | `fix: handle null pointer in login` |
| `feat:` | Minor | `feat: add password reset flow` |
| `BREAKING CHANGE:` | Major | `feat(api): change response format\n\nBREAKING CHANGE: paginated responses` |
