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
