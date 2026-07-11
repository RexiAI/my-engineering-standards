# Testing Standards

All projects must have tests. The testing strategy has three layers:

| Layer | Scope | Framework | Speed | Run frequency |
|---|---|---|---|---|
| Unit | Single class/function in isolation | JUnit 5 + Mockito / Go testing + testify / Jest | Fast | Every commit |
| Integration | With infrastructure (DB, Redis, SQS) | TestContainers + Spring Boot / Docker compose | Medium | Every PR |
| E2E | Full service Dockerized + stubs | RESTEasy / WireMock / ExtentReports / Docker compose | Slow | CI pipeline |

## Unit Tests

- Test files mirror source package structure. One test class per production class.
- Name tests describing the scenario and expected outcome: `shouldReturnErrorWhenUserNotFound`.
- **Java**: Use JUnit 5 (`@ExtendWith(MockitoExtension.class)`), Mockito for mocks, AssertJ for assertions. Avoid loading Spring context in unit tests. Use ObjectMother pattern for test data factories.
- **Go**: Use `testing` package with `testify/suite`. Generate mocks via `github.com/golang/mock` with `gomockhandler.json`.
- **JS/TS**: Use Jest. Prefer React Testing Library for component tests. Use Snapshot Testing sparingly (only for stable components).

### Test Data (ObjectMother Pattern)

Create factory classes that generate test data with sensible defaults and overrides:

```java
public class IdentityClaimsMother {
    public static IdentityClaims randomIdentity() { ... }
    public static IdentityClaims withRoles(String... roles) { ... }
}
```

## Integration Tests

Integration tests validate the service against real infrastructure ran via TestContainers or Docker compose.

### Java Integration Test Annotations (from test-utils)

- `@IntegrationTest(classes = Application.class)` — loads full Spring context.
- `@RedisSuite` — starts Redis TestContainer.
- `@LocalstackSuite` — starts LocalStack (SQS, DynamoDB, S3, KMS, SSM).
- `@MockServerSuite` — starts MockServer for HTTP stubs.
- `@RDBMSSuite` — starts PostgreSQL TestContainer with Flyway migration.
- `@ServiceTest` — composite for all the above.

### Go Integration Tests

Use `testcontainers-go` with Docker compose for infrastructure. Test files end with `_test.go` and use build tags when needed (`//go:build integration`).

## E2E Tests

E2E tests run the full service in a Docker container alongside all dependencies (PostgreSQL, Redis, LocalStack, WireMock mocks). They verify real HTTP endpoints against the running service.

### Structure

```
src/service-tests/java/com/company/servicetests/
├── AbstractBaseTestSuite.java
├── health/HealthTest.java
├── admin/configuration/ConfigurationTest.java
└── ...
```

The test suite:
1. Starts Spring in test-client mode (no web server).
2. Configures `WireMock` pointing at `mock-service:80` to stub upstream services.
3. Provides helpers: `service()` (HTTP client to service under test), `checkThat()` (Hamcrest assertions).
4. Generates structured reports via ExtentReports.

### E2E Test Client Pattern

```java
@ServiceProvider extends BaseServiceProvider {
    // Holds BaseApi instances for each API endpoint group
}

BaseApi {
    // RESTEasy/JAX-RS HTTP client: get(), post(), put(), delete()
    // Pre-built methods for health, metrics, configuration endpoints
}
```

## Code Coverage

- **Java**: JaCoCo with minimum coverage targets configured in parent POM. Coverage reports generated during `prepare-package` phase.
- **Go**: `go test -coverprofile=reports/coverage/coverage.out`. HTML and XML (Cobertura) reports.
- **CI**: Coverage reports published to SonarQube. Coverage must not decrease from baseline.

## Mutation Testing

Mutation testing validates that tests actually catch bugs by introducing small changes (mutations) to production code and verifying that at least one test fails. High line coverage alone does not guarantee useful tests — mutation coverage measures test quality.

- **Java**: PiTest (`pitest-maven` plugin, profile-activated). Run with `mvn verify -Pmutation`. Target mutation coverage >= 80%. Configured in parent POM.
- **Go**: `go-mutesting` or manual mutation analysis on critical paths.
- **JS/TS**: Stryker Mutator for JavaScript/TypeScript projects. Run with `npx stryker run`.
- Run mutation tests periodically (not every commit — too slow). Run before major releases and when adding tests to ensure they are effective.

## Static Analysis

| Tool | Scope | Enforced |
|---|---|---|
| Spotless (Google Java Format) | Java formatting | Build (compile phase) |
| SpotBugs + FindSecBugs | Java bugs + security | Build (package phase) |
| PMD + CPD | Java defects + copy-paste | Build (verify phase) |
| Checkstyle | Java style (optional) | Manual |
| golangci-lint | Go linting | CI |
| ESLint | JS/TS linting | Build / CI |
| Prettier | JS/TS formatting | Build / CI |
| OWASP Dependency Check | Dependency vulnerability scan | CI (profile-activated) |
| SonarQube | Overall code quality | CI |
| Talisman | Secret pre-commit hook | Pre-commit |
