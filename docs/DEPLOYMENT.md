# Deployment Standards

## CI/CD

All CI/CD is managed via **Atlassian Bamboo** using Bamboo Specs (configuration-as-code in Java).

### Bamboo Specs Structure

```
bamboo-specs/
├── pom.xml
└── src/main/java/
    └── PlanSpec.java
```

### Plan Generation Helpers

Use shared helper classes from the `ok-bamboo` library:

- `SSSJavaHelper.createSpringBootPlans()` — generates build plans for Spring Boot microservices. Includes Maven build, service tests, security scanning (Checkmarx), and Swagger deployment.
- `GolangHelper.createGolangPlans()` — generates plans for Go services.
- `GolangHelper.createGolangLibraryPlans()` — generates plans for Go libraries.

### Plan Features

- Maven build with service profile.
- Docker-based service tests (`docker-compose up` with all dependencies).
- Security scanning (Checkmarx).
- OWASP dependency check.
- SonarQube analysis and quality gate.
- Swagger/OpenAPI spec deployment.
- Image publishing to container registry.

## Docker Patterns

### Java Services

```dockerfile
FROM amazoncorretto:17 AS build
WORKDIR /app
COPY target/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract

FROM amazoncorretto:17
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
FROM golang:1.26 AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/service ./src/main.go

FROM alpine:3.18
RUN apk --no-cache add ca-certificates tzdata
COPY --from=build /app/service /service
USER 1000
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1
ENTRYPOINT ["/service"]
```

### Docker Compose for Service Tests

Each project has a `dockerfiles/common-services.yml` defining the service test infrastructure:

- `localstack` — AWS service emulation (SQS, SNS, DynamoDB, KMS, SSM).
- `redis` — Redis with TLS.
- `elb-mock` — ELB health check mocking (Mountebank).
- `mock-service` — WireMock for stubbing upstream services.
- `rdbms` — PostgreSQL with Flyway migrations.
- `rproxy` — Nginx reverse proxy mapping AWS endpoints to local mock services.
- `setup-service-resources` — Populate configuration and SSM parameters.
- `setup-service-data` — Seed test data.
- `service-tests` — The test runner (links to all above).

## Artifact Management

All Maven artifacts are published to a private Nexus instance:
- Releases: `https://nexus.ods.ok-cloud.net/repository/ok-artifacts/`
- Snapshots: `https://nexus.ods.ok-cloud.net/repository/ok-artifacts-snapshot/`

Maven repositories are configured in the parent POM. Developers should never commit repository passwords.

## Environment Configuration

- **Development**: Local YAML config files loaded from `config/` directory.
- **Testing**: Docker compose with local emulators (LocalStack).
- **Production**: AWS SSM Parameter Store at path `/config/{SERVICE_NAME}_{ENVIRONMENT}/`.
- **Feature flags**: Environment variables prefixed by service name.
- **Secrets**: AWS KMS + Parameter Store. Never in config files or environment variables.

## Quality Gates

CI pipeline must pass these checks before merging:
1. All unit tests pass.
2. JaCoCo coverage >= configured minimum (no decrease).
3. Spotless formatting check passes.
4. SpotBugs + FindSecBugs shows no new issues.
5. PMD shows no new violations.
6. OWASP Dependency Check shows no critical/high vulnerabilities.
7. SonarQube quality gate passes (no new bugs, code smells, security hotspots).
8. Service tests (E2E) pass.
9. Talisman secret scan passes (pre-commit hook).
