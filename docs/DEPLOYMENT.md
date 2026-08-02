# Deployment Standards

## CI/CD

Default: GitHub Actions (`.github/workflows/`). CI runs on a standard runner/VM — no specific cloud or VPS is prescribed.

### Pipeline Steps

- Build: `mvn clean install -Pservice` (Java) or `make build` (Go)
- Contract tests: Pact consumer/provider verification (every PR, see CI_CD.md)
- E2E tests: `docker compose up` with all dependencies, test runner connects via Docker network (weekly schedule)
- Resilience verification: smoke test with circuit breaker simulation (pre-release)
- Security: OWASP dependency check, static analysis, secret scan
- SonarQube/SonarCloud quality gate
- Observability validation: health check, metrics endpoint verified
- Publish artifact/image to registry

## Docker Patterns

### Java Services

```dockerfile
FROM amazoncorretto:21 AS build
WORKDIR /app
COPY target/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract

FROM amazoncorretto:21
RUN yum -y install openssl ca-certificates && yum clean all
COPY --from=build app/dependencies/ ./
COPY --from=build app/spring-boot-loader/ ./
COPY --from=build app/snapshot-dependencies/ ./
COPY --from=build app/application/ ./
USER 1000
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s CMD curl -f http://localhost:8080/health || exit 1
ENTRYPOINT ["java", "org.springframework.boot.loader.JarLauncher"]
```

### Go Services

```dockerfile
ARG GO_VERSION=1.26
FROM golang:${GO_VERSION} AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/service ./cmd/server

FROM alpine:3.18
RUN apk --no-cache add ca-certificates tzdata
COPY --from=build /app/service /service
USER 1000
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1
ENTRYPOINT ["/service"]
```

Never hardcode a language runtime version in more than one place. `GO_VERSION` here should be passed via `--build-arg GO_VERSION=$(go list -m -f '{{.GoVersion}}')` (or read `go.mod`/`toolchain` directly) so the image always matches the module's declared version — see docs/CI_CD.md §Toolchain Versions.

### Docker Compose for E2E Tests

Each project has a `docker-compose.yml` defining the E2E test infrastructure:

- `localstack` — AWS service emulation (SQS, SNS, DynamoDB, KMS, SSM).
- `redis` — Redis cache.
- `mock-service` — WireMock for stubbing upstream services.
- `rdbms` — PostgreSQL with migration tooling.
- `reverse-proxy` — Nginx reverse proxy mapping cloud endpoints to local mock services.
- `setup-service-resources` — Populate configuration and secrets.
- `setup-service-data` — Seed test data.
- `e2e-tests` — The test runner (links to all above).

## Artifact Management

All Maven artifacts are published to GitHub Packages (Maven repository, `server-id: github` in `.github/workflows/backend/ci-java.yml`), authenticated via `MAVEN_USERNAME`/`MAVEN_PASSWORD` secrets. Docker images are pushed to GHCR. See docs/CI_CD.md for the exact `deploy`/`docker` job definitions.

Maven repositories are configured in the parent POM. Developers should never commit repository passwords.

## Environment Configuration

- **Development**: Local config files loaded from `config/` directory.
- **Testing**: Docker compose with local service emulators (LocalStack, TestContainers, etc.).
- **Production**: Configuration from environment variables or a config service (HashiCorp Vault, AWS SSM, Kubernetes ConfigMaps, etc.).
- **Feature flags**: Environment variables prefixed by service name.
- **Secrets**: Prefer environment variables for small projects. Use a secrets manager for larger deployments. Never in config files or committed to version control.

## Quality Gates

CI pipeline must pass these checks before merging:
1. All unit tests pass.
2. JaCoCo coverage >= configured minimum (no decrease).
3. Spotless formatting check passes.
4. SpotBugs + FindSecBugs shows no new issues.
5. PMD shows no new violations.
6. OWASP Dependency Check shows no critical/high vulnerabilities.
7. SonarQube quality gate passes (no new bugs, code smells, security hotspots).
8. Contract tests pass (Pact consumer/provider verification, runs on every PR — see docs/CI_CD.md).
9. Talisman secret scan passes (pre-commit hook).

Full E2E tests run on a weekly schedule against staging (`ci-e2e-weekly.yml`), not as a pre-merge gate — see docs/CI_CD.md §Weekly E2E Pipeline. A failing weekly E2E run does not block PR merges; it pages the on-call rotation for triage. `mvp`-tier projects (docs/CONFORMANCE_TIERS.md) without a staging environment run E2E on every push instead — see docs/TESTING.md §E2E Tests.

## Quality Gate Verdicts: Tri-State, Not Binary

A review or CI gate script's exit code should distinguish "blocking" from "worth a human look" rather than collapsing everything into pass/fail:

| Exit code | Verdict | Meaning |
|---|---|---|
| `0` | **APPROVED** | All checks pass. Safe to ship. |
| `1` | **CONDITIONAL** | Non-blocking issues found (e.g. a file over the soft LOC guideline, a dependency added without an obvious justification). Review before merging, don't auto-block. |
| `2` | **REJECTED** | Blocking failures (failing tests, a security scan hit, a broken build). Fix before shipping. |

A binary pass/fail forces every advisory signal to be either silently dropped or treated as a hard blocker — neither is right. `CONDITIONAL` gives advisory findings a place to live that isn't "ignored."

## Stale Compiled Artifacts in Containers

For any compiled-language service running in a container during local dev: restarting the container does not rebuild the binary. If the build step isn't part of the restart path, the container comes back up running the *old* code with no error — the deploy silently didn't happen. State this explicitly wherever the rebuild step lives (a Makefile target, a runbook entry): `docker compose build api && docker compose up -d api`, not just `docker compose restart api`.

### Conditional Gates (Saga/Outbox Pattern)

Gates 10–14 activate automatically when `detect-saga-outbox.sh` finds saga or outbox code
in the changed files. Zero overhead for services that do not use these patterns.
Enable via `init-ci.sh --with-saga` (GitLab only — GitHub Actions has no saga/outbox gate job yet).

10. **Saga compensation completeness** (if saga code present) — every `@SagaHandler` / `*SagaHandler`
    function must have a matching compensation method (`on*Failed`, `compensate*`, `rollback*`).
    Enforced by ArchUnit `SagaArchRules` (Java), `go-saga-lint.go` (Go), or ESLint
    `saga/compensation-required` (Node). Reference: `docs/SAGA_PATTERN.md §CI Quality Gates`.

11. **Outbox schema validation** (if outbox code present) — migration files must define the
    outbox table with all required columns, a partial index on `published_at IS NULL`, and a
    cleanup mechanism. Enforced by `scripts/lint-outbox-schema.sh`.
    Reference: `docs/OUTBOX_PATTERN.md §CI Quality Gates`.

12. **Saga timeout enforcement** (if saga code present) — every saga step must declare a timeout
    (`@Timeout` / `context.WithTimeout` / `timeout` property). Enforced by
    `scripts/check-saga-timeouts.sh`. Reference: `docs/SAGA_PATTERN.md §Saga Timeout`.

13. **Saga/outbox integration tests present** (if either pattern present) — test files matching
    `*SagaTest*` or `*OutboxTest*` must exist and contain compensation/relay test scenarios.
    Enforced by `scripts/check-saga-tests.sh`. Templates in `ci/templates/tests/`.
    Reference: `docs/SAGA_PATTERN.md §Required Tests`, `docs/OUTBOX_PATTERN.md §Required Tests`.

14. **Consumer deduplication verified** (if outbox code present) — event consumer code must
    reference a deduplication store (`*DedupStore`, `alreadyProcessed`, `SetNX`). Enforced by
    `scripts/check-outbox-relay.sh`. Reference: `docs/OUTBOX_PATTERN.md §Idempotent Event Processing`.

## Production Deployment: Kamal + VPS

### Overview

For small teams seeking a simple, cloud-agnostic deployment path: deploy Docker images to a VPS
using [Kamal](https://github.com/basecamp/kamal) (by Basecamp). Kamal builds on Docker Compose
and adds zero-downtime deploys, Traefik reverse proxy with automatic Let's Encrypt TLS, SSH-based
rolling updates, and host-level health checks.

**Cost**: ~$5–12/mo for a single VPS (Hetzner AX11, DigitalOcean Basic, etc.).
**Complexity**: Zero Kubernetes. Just Docker + Kamal on Ubuntu.

### Prerequisites

1. A VPS running Ubuntu 22.04+ (or Debian 12+) with SSH access.
2. A domain name with DNS pointing to the VPS.
3. Docker installed on the VPS (Kamal installs and manages Docker automatically on first run).

### Initial Setup

#### 1. Bootstrap deploy configuration in your repo

From your project root (which has `.standards/` as a submodule):

```bash
.standards/scripts/init-deploy.sh \
  --platform github \
  --host <VPS_IP> \
  --service-name my-api \
  --app-domain api.example.com
```

For a monorepo with both backend and frontend:

```bash
.standards/scripts/init-deploy.sh \
  --platform github \
  --host <VPS_IP> \
  --backend go \
  --frontend nextjs \
  --service-name my-api \
  --app-domain app.example.com
```

This creates:
- `.kamal/config.rb` — Kamal deployment config
- `.kamal/.env.example` — Environment variables template
- `.kamal/secrets/` — SSH key storage directory
- Updates `.github/workflows/ci.yml` with a `deploy` job (if it doesn't exist)

#### 2. Add SSH key to CI/CD secrets

Generate an SSH key pair (without a passphrase):

```bash
ssh-keygen -t ed25519 -C "deploy@your-vps" -f ~/.ssh/deploy-vps -N ""
```

Add the **private key** content to your repo's CI/CD secrets:

| Provider | Secret Name | Value |
|---|---|---|
| GitHub Actions | `SSH_PRIVATE_KEY` | Contents of `~/.ssh/deploy-vps` |
| GitLab CI | `SSH_PRIVATE_KEY` | Same |

Also add these secrets:

| Secret | Example | Required |
|---|---|---|
| `SSH_HOST` | `123.45.67.89` | Yes |
| `SSH_USER` | `root` | Yes |
| `SSH_PORT` | `22` (default) | Optional |
| `APP_DOMAIN` | `api.example.com` | Yes |
| `GHCR_TOKEN` | GitHub token with `write:packages` | Yes |

#### 3. Bootstrap the VPS

SSH into your VPS as root and install Docker:

```bash
# On the VPS
apt-get update && apt-get install -y docker.io
dockerd &
```

Add your deploy SSH key to the VPS:

```bash
# On the VPS
mkdir -p ~/.ssh
echo "ssh-ed25519 AAAA... deploy@your-vps" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

#### 4. First deploy

```bash
cd your-project
cp .kamal/.env.example .kamal/.env
# Edit .kamal/.env with your values
source .kamal/.env
kamal setup
```

### CI/CD Pipeline Composition

After `init-ci.sh --with-deploy` or `init-deploy.sh` runs, your child repo's
`.github/workflows/ci.yml` will have a deploy job chained after the CI build:

```yaml
jobs:
  backend-ci:
    uses: RexiAI/my-engineering-standards/.github/workflows/backend/ci-go.yml@main
    with:
      docker-registry: ghcr.io
    secrets:
      GHCR_TOKEN: ${{ secrets.GHCR_TOKEN }}

  deploy:
    needs: [backend-ci]
    if: github.event_name == 'push' && github.ref_name == github.event.repository.default_branch
    uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-deploy.yml@main
    with:
      service-name: my-api
      docker-registry: ghcr.io
    secrets:
      SSH_HOST: ${{ secrets.SSH_HOST }}
      SSH_USER: ${{ secrets.SSH_USER }}
      SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
      SSH_PORT: ${{ secrets.SSH_PORT }}
      GHCR_TOKEN: ${{ secrets.GHCR_TOKEN }}
```

For GitLab CI, your `.gitlab-ci.yml` includes the deploy template:

```yaml
include:
  - local: .standards/ci/gitlab/gitlab-ci.yml
  - local: .standards/ci/gitlab/backend/ci-go.yml
  - local: .standards/ci/templates/child-ci-deploy.yml

deploy-prod:
  extends: .kamal-deploy
  stage: deploy
  variables:
    SERVICE_NAME: "my-api"
```

### Guard Clause: Safe Skipping

If deployment secrets are not configured, the CI deploy job **skips gracefully** (exits 0).
This means:

- ✅ CI pipeline stays green
- ✅ PRs merge successfully
- ✅ Image builds and pushes to GHCR work normally
- ❌ Production deploy does not happen (expected — no infra configured)

This lets you set up CI/CD first, push images, and configure production deployment
as a separate step — no coordination needed.

### Service Type Configuration

| Type | Service name env | Health endpoint | Port |
|---|---|---|---|
| Java (Spring Boot) | `SERVICE_NAME` | `/actuator/health` | `8080` |
| Go | `SERVICE_NAME` | `/health` | `8080` |
| Node.js (NestJS) | `SERVICE_NAME` | `/health` | `3000` |
| Next.js | `FRONTEND_SERVICE_NAME` | `/` | `3000` |

Override defaults in `.kamal/config.rb` via env vars:

```ruby
# .kamal/config.rb
set :health_check, url: "http://my-service:8080/actuator/health",
                    interval: 30, timeout: 5, max_checks: 30
```

### Secrets Management

- **CI secrets** (SSH key, host) → set as CI/CD variables/secrets
- **App secrets** (DATABASE_URL, API keys) → set as `KAMAL_ENV_*` variables in CI/CD
  or via `.kamal/secrets/` on the server
- **Never commit secrets** to the repo

```yaml
# Example: forwarding app secrets from CI environment
env:
  KAMAL_ENV_DATABASE_URL: ${{ secrets.DATABASE_URL }}
  KAMAL_ENV_API_KEY: ${{ secrets.API_KEY }}
```

### Zero-Downtime Deploys

Kamal performs rolling deploys:
1. New container starts alongside the old one
2. Health check passes
3. Traffic switches (via Traefik)
4. Old container is removed

### Rollback

```bash
# List deployments
kamal deploy list

# Rollback to previous
kamal rollback
```

### VPS Provider Recommendations

| Provider | 1 vCPU + 1GB | Notes |
|---|---|---|
| Hetzner Cloud AX11 | €4.58/mo | Best value for EU |
| DigitalOcean Basic | $4/mo | Simple, reliable |
| Vultr | $5/mo | Global regions |
| AWS EC2 t4g.nano | $3.60/mo | ARM, free tier eligible |

Install Docker on VPS:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker $USER  # if not root
```
