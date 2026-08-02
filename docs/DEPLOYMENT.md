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

## Production Deployment

### Choosing a Backend

All backends deploy the Docker image your CI pipeline already builds and pushes to
GHCR on merge to `main`. The only difference is **where** the container runs and
**which tool** orchestrates it.

| Aspect | Kamal | Dokku | Raw SSH + Compose |
|---|---|---|---|
| Runtime | Docker on VPS | Dokku PaaS on VPS | Docker on VM/EC2 |
| Deploy command | `kamal deploy` | `dokku git:from-image` | `docker compose up -d` |
| Config in repo | `.kamal/config.rb` | none (host state) | `docker-compose.prod.yml` + `nginx.conf` |
| Reverse proxy | Traefik (auto) | Nginx (built-in) | Nginx (template) |
| TLS | Let's Encrypt (auto) | letsencrypt plugin | certbot |
| Zero-downtime | ✅ built-in | ✅ built-in | Manual (rolling) |
| Rollback | `kamal rollback` | `dokku releases:rollback` | Manual |
| Multi-service | Native | One app per service | Compose |
| Fits | Teams that want one tool, minimal config | Teams that want a Heroku-like PaaS | Teams on AWS/EC2, want full control |

Choose with `init-deploy.sh --deploy-tool <kamal|dokku|ssh>` or
`init-ci.sh --deploy-tool <kamal|dokku|ssh>`. Default is `kamal`.

### Backend: Kamal + VPS

#### Overview

[Kamal](https://github.com/basecamp/kamal) (by Basecamp) builds on Docker Compose and adds
zero-downtime deploys, Traefik reverse proxy with automatic Let's Encrypt TLS, SSH-based
rolling updates, and host-level health checks.

**Cost**: ~$5–12/mo for a single VPS (Hetzner AX11, DigitalOcean Basic, etc.).
**Complexity**: Zero Kubernetes. Just Docker + Kamal on Ubuntu.

#### Prerequisites

1. A VPS running Ubuntu 22.04+ (or Debian 12+) with SSH access.
2. A domain name with DNS pointing to the VPS.
3. Docker installed on the VPS (Kamal installs and manages Docker automatically on first run).

#### Initial Setup

```bash
.standards/scripts/init-deploy.sh \
  --platform github \
  --deploy-tool kamal \
  --host <VPS_IP> \
  --service-name my-api \
  --app-domain api.example.com
```

This creates:
- `.kamal/config.rb` — Kamal deployment config
- `.kamal/.env.example` — Environment variables template
- `.deploy/secrets/` — SSH key storage directory
- Updates `.github/workflows/ci.yml` with a `deploy` job (if it doesn't exist)

Add the SSH private key + `SSH_HOST`, `SSH_USER`, `SSH_PORT` to CI secrets, then
bootstrap the VPS and first-deploy:

```bash
# On the VPS: install Docker (Kamal manages Traefik itself)
scp .standards/templates/setup-host.sh root@<VPS_IP>:/tmp/
ssh root@<VPS_IP> "bash /tmp/setup-host.sh --backend kamal"

# From your repo: first deploy
cd your-project
cp .kamal/.env.example .kamal/.env
source .kamal/.env
kamal setup
```

#### CI/CD Pipeline Composition

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
    uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-deploy-kamal.yml@main
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

For GitLab CI:

```yaml
include:
  - local: .standards/ci/gitlab/gitlab-ci.yml
  - local: .standards/ci/gitlab/backend/ci-go.yml
  - local: .standards/ci/templates/child-ci-deploy-kamal.yml

deploy-prod:
  extends: .kamal-deploy
  stage: deploy
  variables:
    SERVICE_NAME: "my-api"
```

#### Service Type Configuration

| Type | Service name env | Health endpoint | Port |
|---|---|---|---|
| Java (Spring Boot) | `SERVICE_NAME` | `/actuator/health` | `8080` |
| Go | `SERVICE_NAME` | `/health` | `8080` |
| Node.js (NestJS) | `SERVICE_NAME` | `/health` | `3000` |
| Next.js | `FRONTEND_SERVICE_NAME` | `/` | `3000` |

Override defaults in `.kamal/config.rb`:

```ruby
set :health_check, url: "http://my-service:8080/actuator/health",
                    interval: 30, timeout: 5, max_checks: 30
```

#### Secrets Management

- **CI secrets** (SSH key, host) → set as CI/CD variables/secrets
- **App secrets** (DATABASE_URL, API keys) → set as `KAMAL_ENV_*` variables in CI/CD
  or via `.kamal/secrets/` on the server
- **Never commit secrets** to the repo

```yaml
env:
  KAMAL_ENV_DATABASE_URL: ${{ secrets.DATABASE_URL }}
  KAMAL_ENV_API_KEY: ${{ secrets.API_KEY }}
```

#### Rollback

```bash
kamal deploy list
kamal rollback
```

### Backend: Dokku + VPS

#### Overview

[Dokku](https://dokku.com) is a self-hosted PaaS (like Heroku) that runs on a single VPS.
It manages Nginx routing, Let's Encrypt TLS, and process supervision. Deploy via
`dokku git:from-image` from a pre-built Docker image (consistent with the GHCR push flow).

**Cost**: ~$5–12/mo for a single VPS.
**Fits**: Teams that want a Heroku-like workflow without paying for Heroku.

#### Initial Setup

```bash
.standards/scripts/init-deploy.sh \
  --platform github \
  --deploy-tool dokku \
  --host <VPS_IP> \
  --user root \
  --service-name my-api \
  --app-domain api.example.com
```

This creates:
- `.deploy/dokku.env.example` — environment template
- `.deploy/secrets/` — SSH key storage directory
- Updates `.github/workflows/ci.yml` with a `deploy` job (if it doesn't exist)

Bootstrap the VPS with Dokku:

```bash
scp .standards/templates/setup-host.sh root@<VPS_IP>:/tmp/
ssh root@<VPS_IP> "bash /tmp/setup-host.sh --backend dokku --domain api.example.com"
```

One-time app setup:

```bash
ssh root@<VPS_IP> "dokku apps:create my-api"
ssh root@<VPS_IP> "dokku letsencrypt:enable my-api"
```

#### CI/CD Pipeline Composition

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
    uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-deploy-dokku.yml@main
    with:
      service-name: my-api
      dokku-app-name: my-api
      docker-registry: ghcr.io
    secrets:
      SSH_HOST: ${{ secrets.SSH_HOST }}
      SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
```

> **Note**: `SSH_USER` defaults to `dokku` for this backend. Dokku routes deploys over the
> `dokku` user, so configure the SSH key for that user on the host.

For GitLab CI:

```yaml
include:
  - local: .standards/ci/gitlab/gitlab-ci.yml
  - local: .standards/ci/gitlab/backend/ci-go.yml
  - local: .standards/ci/templates/child-ci-deploy-dokku.yml

deploy-prod:
  extends: .dokku-deploy
  stage: deploy
  variables:
    SERVICE_NAME: "my-api"
```

#### Secrets

| Secret | Example | Required |
|---|---|---|
| `SSH_HOST` | `123.45.67.89` | Yes |
| `SSH_USER` | `dokku` | No (defaults to `dokku`) |
| `SSH_PRIVATE_KEY` | — | Yes |
| `DOKKU_APP_NAME` | `my-api` | No (defaults to `service-name`) |
| `GHCR_TOKEN` | — | Yes (host pulls from GHCR) |

#### Rollback

```bash
ssh dokku@<HOST> "dokku releases:list my-api"
ssh dokku@<HOST> "dokku releases:rollback my-api <release>"
```

### Backend: Raw SSH + Docker Compose

#### Overview

Deploy to any raw VM — including AWS EC2 — by SSHing in and running
`docker compose up`. You control the reverse proxy (nginx template) and TLS (certbot).
No PaaS, no deploy framework — just Docker.

**Cost**: ~$3.60–12/mo (EC2 t4g.nano or any VPS).
**Fits**: Teams already on AWS/EC2, or that want full control over the host.

#### Initial Setup

```bash
.standards/scripts/init-deploy.sh \
  --platform github \
  --deploy-tool ssh \
  --host <VM_IP> \
  --service-name my-api \
  --app-domain api.example.com
```

This creates:
- `docker-compose.prod.yml` — production compose (references `${IMAGE}` injected by CI)
- `nginx.conf` — reverse proxy + TLS template (replace `example.com`)
- `setup-host.sh` — one-time VPS bootstrap
- `.deploy/env.example` — environment template
- Updates `.github/workflows/ci.yml` with a `deploy` job (if it doesn't exist)

Bootstrap the host (installs Docker + nginx + certbot, sets renewal cron):

```bash
scp setup-host.sh root@<VM_IP>:/tmp/
ssh root@<VM_IP> "bash /tmp/setup-host.sh --backend ssh --domain api.example.com"
```

Install the nginx site and obtain the TLS cert once:

```bash
scp nginx.conf root@<VM_IP>:/etc/nginx/sites-available/api.example.com.conf
ssh root@<VM_IP> \
  "ln -sf /etc/nginx/sites-available/api.example.com.conf /etc/nginx/sites-enabled/ && nginx -t && systemctl reload nginx && certbot --nginx -d api.example.com"
```

#### CI/CD Pipeline Composition

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
    uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-deploy-ssh.yml@main
    with:
      service-name: my-api
      docker-registry: ghcr.io
    secrets:
      SSH_HOST: ${{ secrets.SSH_HOST }}
      SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
```

For GitLab CI:

```yaml
include:
  - local: .standards/ci/gitlab/gitlab-ci.yml
  - local: .standards/ci/gitlab/backend/ci-go.yml
  - local: .standards/ci/templates/child-ci-deploy-ssh.yml

deploy-prod:
  extends: .ssh-deploy
  stage: deploy
  variables:
    SERVICE_NAME: "my-api"
```

#### Secrets

| Secret | Example | Required |
|---|---|---|
| `SSH_HOST` | `123.45.67.89` or EC2 public IP | Yes |
| `SSH_USER` | `ubuntu` / `ec2-user` | No (defaults to `root`) |
| `SSH_PRIVATE_KEY` | — | Yes |
| `APP_DIR` | `/opt/my-api` | No (defaults to `/opt/<service>`) |

#### Rollback

Manual — SSH in and point the compose file at a previous image:

```bash
ssh root@<VM_IP> "cd /opt/my-api && export IMAGE=ghcr.io/org/my-api:<prev-sha> && docker compose -f docker-compose.prod.yml up -d --force-recreate"
```

### Guard Clause: Safe Skipping

All three backends share the same guard clause. If deployment secrets are not
configured, the CI deploy job **skips gracefully** (exits 0). This means:

- ✅ CI pipeline stays green
- ✅ PRs merge successfully
- ✅ Image builds and pushes to GHCR work normally
- ❌ Production deploy does not happen (expected — no infra configured)

This lets you set up CI/CD first, push images, and configure production deployment
as a separate step — no coordination needed.

### VPS Provider Recommendations

| Provider | 1 vCPU + 1GB | Notes |
|---|---|---|
| Hetzner Cloud AX11 | €4.58/mo | Best value for EU |
| DigitalOcean Basic | $4/mo | Simple, reliable |
| Vultr | $5/mo | Global regions |
| AWS EC2 t4g.nano | $3.60/mo | ARM, free tier eligible |
