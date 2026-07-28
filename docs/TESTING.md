# Testing Standards

All projects must have tests. The testing strategy has three layers:

| Layer       | Scope                                | Framework                                            | Speed  | Run frequency |
| ----------- | ------------------------------------ | ---------------------------------------------------- | ------ | ------------- |
| Unit        | Single class/function in isolation   | JUnit 5 + Mockito / Go testing + testify / Jest      | Fast   | Every commit  |
| Integration | With infrastructure (DB, Redis, SQS) | In-memory (H2, embedded-redis, WireMock)             | Fast   | Every commit  |
| E2E         | Full service Dockerized + stubs      | RESTEasy / WireMock / ExtentReports / Docker compose | Slow   | Weekly (scheduled)  |

## Unit Tests

- Test files mirror source package structure. One test class per production class.
- Name tests describing the scenario and expected outcome: `shouldReturnErrorWhenUserNotFound`.
- **Java**: Use JUnit 5 (`@ExtendWith(MockitoExtension.class)`), Mockito for mocks, AssertJ for assertions. Avoid loading Spring context in unit tests.
- **Go**: Use `testing` package with `testify/suite`. Generate mocks via `github.com/golang/mock` with `gomockhandler.json`.
- **JS/TS**: Use Jest. Prefer React Testing Library for component tests. Use Snapshot Testing sparingly (only for stable components).

### Test Data (Builder Pattern)

Prefer the Test Data Builder pattern (composable, keeps test data local):

```java
public class TestUser {
    private String role = "USER";
    private String channel = "WEB";

    public TestUser withRole(String role) { this.role = role; return this; }
    public TestUser withChannel(String channel) { this.channel = channel; return this; }
    public IdentityClaims build() { return new IdentityClaims(role, channel); }
}
// Usage in test:
new TestUser().withRole("ADMIN").build();
```

ObjectMother is acceptable for simple cases. Prefer builders when objects have many fields with different test combinations.

## Integration Tests

Integration tests validate the service against real infrastructure. Prefer in-memory alternatives — they run 10-50x faster and require no Docker:

| Dependency | In-memory alternative |
|---|---|
| PostgreSQL / MySQL | H2 (Java), SQLite `:memory:` (Go, JS) |
| Redis | embedded-redis (Java), miniredis (Go), ioredis-mock (JS) |
| HTTP dependencies | WireMock (Java), httptest (Go stdlib), nock/MSW (JS) |
| MongoDB | mongodb-memory-server (JS) |
| AWS services | LocalStack (requires Docker — use only when needed) |

Fall back to TestContainers/Docker only when:
- You need a database feature H2/SQLite doesn't support (e.g., PostgreSQL extensions, stored procedures)
- The bug only reproduces against real infrastructure
- You're writing E2E tests (these need real containers by definition)

### Java Integration Tests

```java
@SpringBootTest
@AutoConfigureMockMvc
public class UserControllerTest {

    @Autowired private MockMvc mockMvc;

    @Test
    void shouldReturnUser() throws Exception {
        mockMvc.perform(get("/v1/users/123"))
            .andExpect(status().isOk());
    }
}
```

Use Spring Boot's `@DataJpaTest` for repository tests (auto-configures H2). Use `embedded-redis` for Redis-dependent integration tests. Use `WireMock` in-process for HTTP dependency stubs.

### Go Integration Tests

```go
// Use SQLite :memory: via any SQL driver that supports it
db, _ := sql.Open("sqlite3", ":memory:")
// Use miniredis for Redis tests
s := miniredis.RunT(t)
// Use httptest for HTTP dependency stubs
srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { ... }))
```

### JS/TS Integration Tests

```typescript
// Use SQLite :memory: via TypeORM or Prisma
// Use nock for HTTP dependency stubs
nock('http://auth-service').post('/v1/validate').reply(200, { valid: true })
// Use ioredis-mock for Redis
const redis = new RedisMock()
```

## E2E Tests

E2E tests run the full service in a Docker container alongside all dependencies (PostgreSQL, Redis, LocalStack, WireMock mocks). They verify real HTTP endpoints against the running service. Full E2E runs on a weekly schedule against staging, not on every PR — contract tests (Pact) cover cross-service compatibility on every PR instead. See docs/CI_CD.md §Weekly E2E Pipeline for the exact trigger.

### E2E Test Client (composition over inheritance)

```java
public class ServiceApi {
    private final Client restClient;
    private final String baseUrl;

    public ServiceApi(String baseUrl) {
        this.baseUrl = baseUrl;
        this.restClient = ClientBuilder.newBuilder().build();
    }

    public HealthStatus getHealth() {
        return restClient.target(baseUrl + "/health")
            .request().get(HealthStatus.class);
    }

    public <T> T post(String path, Object body, Class<T> responseType) {
        return restClient.target(baseUrl + path)
            .request().post(Entity.json(body), responseType);
    }
}
// Usage:
ServiceApi api = new ServiceApi("http://service-under-test:8080");
HealthStatus health = api.getHealth();
```

Prefer a simple REST client wrapper class over inheritance hierarchies (`BaseApi`, `BaseServiceProvider`). Each E2E test creates its own client instance.

### Secure E2E Test Fixtures (BeforeEach over `extends`)

```java
public class HealthTest {
    private ServiceApi api;
    private WireMockServer wireMock;

    @BeforeEach
    void setUp() {
        wireMock = new WireMockServer(options().port(8081));
        wireMock.start();
        api = new ServiceApi("http://service-under-test:8080");
    }

    @AfterEach
    void tearDown() {
        wireMock.stop();
    }

    @Test
    void shouldReturnHealthy() {
        assertThat(api.getHealth().getStatus()).isEqualTo("UP");
    }
}
```

Avoid `AbstractBaseTestSuite` base classes. Use plain `@BeforeEach` and helper methods instead. Each test class owns its own setup. This keeps tests readable, composable, and free from hidden inherited state.

## Code Coverage

- **Java**: JaCoCo with minimum coverage targets configured in parent POM. Coverage reports generated during `prepare-package` phase.
- **Go**: `go test -coverprofile=reports/coverage/coverage.out`. HTML and XML (Cobertura) reports.
- **CI**: Coverage reports published to SonarQube when enabled. This is an advisory, PR-only signal — not a blocking CI gate (see docs/CI_CD.md, `sonar` job is opt-in via `sonar-enabled` and does not block `deploy`). Treat "coverage should not decrease from baseline" as a review guideline, not an enforced gate.

## Test Behavior, Not Implementation

Tests should verify observable behavior, not internal implementation details.

### Do

```java
@Test
void shouldReturnUserWhenFound() {
    given(repository.findById("123")).willReturn(Optional.of(testUser()));

    var response = controller.getUser("123");

    assertThat(response.getStatusCode()).isEqualTo(200);
    assertThat(response.getBody().getEmail()).isEqualTo("user@example.com");
}
```

### Don't

```java
// Tests internal calls, not behavior
@Test
void shouldCallRepositoryWithCorrectId() {
    controller.getUser("123");
    verify(repository).findById("123");  // brittle — breaks on refactor
}
```

### Guidelines

- Mock at service boundaries (repositories, external clients), not internal methods
- Assert on return values, not method invocations
- Avoid `verify()` unless testing side-effect-only methods (event publishing, logging)
- Prefer real implementations for pure domain logic (no mocks needed)
- Use contract tests (Pact) to verify service boundary expectations (see `docs/CONTRACT_TESTING.md`)

## Mutation Testing

Mutation testing validates that tests actually catch bugs by introducing small changes (mutations) to production code and verifying that at least one test fails. High line coverage alone does not guarantee useful tests — mutation coverage measures test quality.

- **Java**: PiTest (`pitest-maven` plugin, profile-activated). Run with `mvn verify -Pmutation`. Target mutation coverage >= 80%. Configured in parent POM.
- **Go**: `go-mutesting` or manual mutation analysis on critical paths.
- **JS/TS**: Stryker Mutator for JavaScript/TypeScript projects. Run with `npx stryker run`.
- Run mutation tests periodically (not every commit — too slow). Run before major releases and when adding tests to ensure they are effective.

## Static Analysis

| Tool                          | Scope                         | Enforced               |
| ----------------------------- | ----------------------------- | ---------------------- |
| Spotless (Google Java Format) | Java formatting               | Build (compile phase)  |
| SpotBugs + FindSecBugs        | Java bugs + security          | Build (package phase)  |
| PMD + CPD                     | Java defects + copy-paste     | Build (verify phase)   |
| Checkstyle                    | Java style (optional)         | Manual                 |
| golangci-lint                 | Go linting                    | CI                     |
| ESLint                        | JS/TS linting                 | Build / CI             |
| Prettier                      | JS/TS formatting              | Build / CI             |
| OWASP Dependency Check        | Dependency vulnerability scan | CI (profile-activated) |
| SonarQube                     | Overall code quality          | CI                     |
| Talisman                      | Secret pre-commit hook        | Pre-commit             |
