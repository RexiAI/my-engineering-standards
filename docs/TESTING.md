# Testing Standards

All projects must have tests. The testing strategy has four layers:

| Layer       | Scope                                | Framework                                            | Speed  | Run frequency |
| ----------- | ------------------------------------ | ---------------------------------------------------- | ------ | ------------- |
| Unit        | Single class/function in isolation   | JUnit 5 + Mockito / Go stdlib testing / Jest         | Fast   | Every commit  |
| Acceptance  | One task's behavior, end to end within the unit boundary | Same frameworks as Unit, named to a scenario ID (see docs/SPEC_PIPELINE.md) | Fast   | Every commit  |
| Integration | With infrastructure (DB, Redis, SQS) | In-memory (H2, embedded-redis, WireMock)             | Fast   | Every commit  |
| E2E         | Full service Dockerized + stubs      | RESTEasy / WireMock / ExtentReports / Docker compose | Slow   | Weekly (scheduled)  |

Acceptance tests are produced by the spec pipeline's Coder stage from
`specs/*/20-acceptance/*.md` scenarios — see `docs/SPEC_PIPELINE.md` for the full
flow. They are ordinary tests in the same framework as unit tests, distinguished
only by naming (the scenario ID) and by preceding implementation rather than
following it.


## Unit Tests

- Test files mirror source package structure. One test class per production class.
- Name tests describing the scenario and expected outcome: `shouldReturnErrorWhenUserNotFound`.
- **Java**: Use JUnit 5 (`@ExtendWith(MockitoExtension.class)`), Mockito for mocks, AssertJ for assertions. Avoid loading Spring context in unit tests.
- **Go**: Use the stdlib `testing` package as the default — it's sufficient for the large majority of tests and adds no dependency. `testify` (assertions) and `github.com/golang/mock`/`gomockhandler` (mock generation) are optional additions for projects with enough table-driven complexity or interface surface to justify them; do not add either as a default. This supersedes the previous blanket "use testify/gomock" guidance, which contradicted docs/CODING_CONVENTIONS.md §Dependencies ("prefer stdlib, justify each dependency").
- **JS/TS**: Use Jest. Prefer React Testing Library for component tests. Use Snapshot Testing sparingly (only for stable components).
- **React Native**: unit and component tests run through Jest with the **jest-expo** preset and [React Native Testing Library](../language-specific/react-native/TESTING.md) — distinct from plain Jest, which does not know how to render native components or mock Expo modules. See `language-specific/react-native/TESTING.md` for the RNTL vs Maestro split and what to mock.

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

E2E tests run the full service in a Docker container alongside all dependencies (PostgreSQL, Redis, LocalStack, WireMock mocks). They verify real HTTP endpoints against the running service.

*Conformance tier for cadence*: `mvp` projects with no staging environment and no cross-service contracts (see docs/CONFORMANCE_TIERS.md) can run E2E on every push/PR instead of weekly — there's no separate contract-test layer to cover PR-time verification, so E2E is doing double duty. `production`+ projects with contract tests covering cross-service compatibility should keep E2E on the weekly schedule against staging and let contract tests cover every PR. See docs/CI_CD.md §Weekly E2E Pipeline for the exact trigger.

### React Native E2E (Maestro)

React Native E2E uses [Maestro](https://maestro.mobile.dev/): YAML flows that drive the real binary on a simulator or device (`maestro test .maestro/`). Because it is emulator-dependent it is a scheduled/optional job, not a per-push gate — see docs/CI_CD.md §React Native (Expo). [Detox](https://wix.github.io/Detox/) is the upgrade path for projects that outgrow Maestro's synchronous control. See `language-specific/react-native/TESTING.md` for the RNTL vs Maestro scope split and flow skeletons.

### One script, run by both CI and local dev

Whatever orchestrates E2E — starting a database, building the binary, starting the server, running the test suite, tearing down — should be a single script that both CI and `make e2e` (or equivalent) invoke, not two copies that can silently diverge. The only difference between the CI and local invocation should be expressible as one environment variable (e.g. "CI already provides a database via a services: block, don't spawn your own container").

### Readiness polling, never a fixed sleep

Wait for a dependency to actually be ready — poll `pg_isready`, poll `/health`, poll the port — with a bounded retry count and an explicit failure message. A fixed `sleep N` either wastes time when the dependency is fast or produces a flaky failure when it's slow; a poll loop does neither.

### Exit-status-preserving cleanup

An E2E script's cleanup trap should capture the real exit status *before* doing any cleanup, dump the service logs only if that status is non-zero (a passing run doesn't need its logs printed), and re-exit with the captured status — not whatever the last cleanup command happened to return. Register the trap before starting anything that needs cleaning up, not after.

### Bounded, justified flake retry

If a test runner's retry setting (e.g. Playwright's `retries:`) is non-zero, the number and the reason belong in a comment next to the setting — "absorbs CPU-contention flakiness under parallel workers; a real, reproducible failure still needs two consecutive fails" is a justification, "flaky tests" is not. Retry count should be as low as still catches the class of flake it's meant for — start at 1, not 3.

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

## Property Testing

*Conformance tier: `production`. See docs/CONFORMANCE_TIERS.md.*

Property tests assert an invariant holds across many generated inputs, instead of
one hand-picked example. Use them for invariants that unit tests already cover with
specific values but that benefit from broader input coverage — "the result is never
negative", "applying an operation twice is idempotent" — not for arbitrary
properties disconnected from the spec's acceptance criteria.

- **Java**: jqwik.
- **Go**: stdlib `testing/quick` — no new dependency, consistent with this repo's
  "prefer stdlib, justify each dependency" rule. Generates simple types (ints,
  strings, slices) well; reach for `pgregory.net/rapid` only if a project's domain
  types need custom generators `testing/quick` can't express.
- **JS/TS**: fast-check.

## Tests That Encode a Defect

A test can assert the currently-wrong behavior. When it does — especially for money,
authorization, or data-retention behavior — fixing the defect necessarily fails that test.
The failure is the correct signal, not an obstacle.

An agent or engineer must **not** silently rewrite such an assertion to make the suite green.
Rewriting it destroys the only record that the behavior changed.

Required procedure when a test fails because it encodes the defect:

1. Stop. Do not edit the assertion yet.
2. Name the specific test and the specific assertion.
3. State why that assertion encodes the defect rather than the intended behavior.
4. Get explicit human authorization before changing it.
5. When authorized, preserve the scenario ID verbatim (traceability — see `docs/SPEC_PIPELINE.md`).
6. Record in the commit or PR body which assertion changed and why.

| Situation | Correct action |
|---|---|
| Test fails after a behavior fix, assertion is still correct | Fix the code |
| Test fails because the assertion encodes the old, wrong behavior | Stop and ask, per the procedure above |
| Test fails and it is unclear which is wrong | Stop and ask — never guess in favor of green |

The general principle: a green suite after a behavior change proves only that the tests agree
with the code. It does not prove that either one is correct.

## Mutation Testing

*Conformance tier: `production`. See docs/CONFORMANCE_TIERS.md.*

Mutation testing validates that tests actually catch bugs by introducing small changes (mutations) to production code and verifying that at least one test fails. High line coverage alone does not guarantee useful tests — mutation coverage measures test quality.

- **Java**: PiTest (`pitest-maven` plugin, profile-activated). Run with `mvn verify -Pmutation`. Target mutation coverage >= 80%. No shared parent POM exists in this repo to pin this centrally — copy `ci/templates/pitest-profile.xml` into each project.
- **Go**: Gremlins (`gremlins unleash`), actively maintained and coverage-aware. See `ci/templates/mutation.mk`. `go-mutesting` was considered and rejected — fewer mutators, unmaintained.
- **JS/TS**: Stryker Mutator for JavaScript/TypeScript projects. Run with `npx stryker run`. See `ci/templates/stryker.conf.json`.
- **React Native**: Stryker with the Jest runner (`testRunner: "jest"`, handles the jest-expo preset). Run with `npx stryker run`. See `ci/templates/stryker.react-native.conf.json`.
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

## CI Failure Diagnostics for Agent Consumers

A CI job's failure needs to be readable by whatever is fixing it. A human can open the Actions log; an AI agent driving CI fixes via an API (e.g. the GitHub MCP tools) typically can read PR comments but not raw Actions logs. When a job that isn't trivially diagnosable from its own status (e.g. E2E) fails on a PR, post a diagnostic comment — the tail of the relevant log, byte-bounded (`tail -c 6000`, not line-bounded — safe against one pathologically long line), wrapped in a collapsed `<details>` block so it doesn't dominate the PR thread. Use the workflow's own `GITHUB_TOKEN`/`github.token`, never a PAT, for the comment.
