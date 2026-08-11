---
name: java
description: Java standards: project shape, build commands, code conventions, test guidance, and pointers to PATTERNS.md / TESTING.md / checkstyle.xml / pmd-rules.xml. Use whenever a child repo uses Java or Spring Boot.
license: See repo root
applyTo: "**/pom.xml, **/*.java"
---

# Java Standards

## Build System

- **Build tool**: Maven.
- **Java version**: 21.
- **Required Maven version**: >= 3.3.9.

## Parent POM

Every Java project inherits from the organization's parent POM:

### For Services (Spring Boot applications)
```xml
<parent>
  <groupId>com.company</groupId>
  <artifactId>parent-pom-service</artifactId>
  <version>${revision}</version>
</parent>
```

### For Libraries
```xml
<parent>
  <groupId>com.company</groupId>
  <artifactId>parent-pom-module</artifactId>
  <version>${revision}</version>
</parent>
```

### CI-friendly Versioning

```xml
<version>${revision}</version>
<properties>
  <revision>1.0.0-SNAPSHOT</revision>
</properties>
```

## Maven Commands

| Command | What it does |
|---|---|
| `mvn clean install -Pservice` | Full build with unit tests, static analysis, formatting check |
| `mvn test -Pservice` | Run unit tests only |
| `mvn verify -Pservice` | Run unit + integration tests |
| `mvn clean install -Pe2e-tests` | Run Docker-based E2E tests |
| `mvn spotless:check` | Check code formatting |
| `mvn spotless:apply` | Fix code formatting |
| `mvn pmd:pmd pmd:cpd` | Run PMD + copy-paste detection |
| `mvn spotbugs:spotbugs` | Run SpotBugs + FindSecBugs |

## Key Dependencies

Managed by the parent POM. Common starters and libraries:

```xml
<dependencies>
  <dependency>com.company:application-starter</dependency>
  <dependency>com.company:company-commons</dependency>
  <dependency>com.company:feign-starter</dependency>
  <dependency>org.springframework.boot:spring-boot-starter-web</dependency>
  <dependency>org.springframework.boot:spring-boot-starter-actuator</dependency>
  <dependency>org.springframework.boot:spring-boot-starter-data-jpa</dependency>
  <dependency>org.springframework.boot:spring-boot-starter-data-redis</dependency>
  <dependency>org.springframework.boot:spring-boot-starter-validation</dependency>
  <dependency>org.springframework.boot:spring-boot-starter</dependency>  <!-- Exclude Tomcat; add Undertow or Jetty as needed -->
</dependencies>
```

All versions are managed by the parent POM. Do not specify versions in child POMs.

## Code Quality Plugins

| Plugin | Phase | Purpose |
|---|---|---|
| spotless-maven-plugin | compile | Google Java Format enforcement |
| spotbugs-maven-plugin | package | Bug patterns + FindSecBugs security analysis |
| pmd-maven-plugin | verify | Best practices, design, error-prone, performance, security |
| jacoco-maven-plugin | prepare-package | Code coverage instrumentation and reports |
| maven-enforcer-plugin | validate | Maven version check, dependency convergence |
| dependency-check-maven | verify | OWASP dependency vulnerability scanning |

## Project Setup

### Main Application Class

```java
@ServiceApplication(exclude = {DataSourceAutoConfiguration.class})
public class Application {
    public static void main(final String[] args) {
        Application.run(Application.class, args);
    }
}
```

### Common Container (Request-scoped)

Prefer a plain class that gets injected, not a template base class:

```java
@Component
@RequestScope
public class CommonContainer {
    private final AuthTokenContainer authToken;
    private final RequestInfoContainer requestInfo;

    public CommonContainer(AuthTokenContainer authToken, RequestInfoContainer requestInfo) {
        this.authToken = authToken;
        this.requestInfo = requestInfo;
    }

    public String getAccessToken() { return authToken.getToken(); }
    public IdentityClaims getIdentity() { return authToken.getIdentity(); }
}
```

### Configuration (Resource bundles)

```java
@Bean
public HandlerInterceptorProvider handlerInterceptorProvider() {
    return new HandlerInterceptorProvider(
        List.of("/admin/**", "/v1/**"),     // Authenticated URLs
        List.of("/v1/public/**")             // Public URLs
    );
}
```

### Health Dependencies

```java
@Bean
public HealthDependencyList healthDependencyList(
    RedisHealthService redisHealthService,
    KmsHealthService kmsHealthService
) {
    return new HealthDependencyList(redisHealthService, kmsHealthService);
}
```

## Error Handling: Result Types

Prefer sealed Result types for expected failures. Reserve exceptions for infrastructure/programming errors.

```java
public sealed interface Result<T, E> {
    record Ok<T, E>(T value) implements Result<T, E> {}
    record Error<T, E>(E error) implements Result<T, E> {}
}

// Service returns result, not exception
public Result<User, CreateUserError> createUser(CreateUserRequest request) {
    if (emailRepository.exists(request.email())) {
        return Result.error(CreateUserError.EMAIL_TAKEN);
    }
    return Result.ok(userRepository.save(request.toUser()));
}

// Controller maps result to HTTP
@PostMapping("/v1/users")
public ResponseEntity<?> createUser(@Valid @RequestBody CreateUserRequest request) {
    return switch (userService.createUser(request)) {
        case Result.Ok(var user) -> ResponseEntity.status(201).body(user);
        case Result.Error(var err) -> switch (err) {
            case EMAIL_TAKEN -> ResponseEntity.status(409)
                .body(Map.of("error", "email taken", "code", "EMAIL_TAKEN"));
            case INVALID_EMAIL -> ResponseEntity.status(422)
                .body(Map.of("error", "invalid email format", "code", "INVALID_EMAIL"));
        };
    };
}
```

### Resilience

Every external client must be wrapped with circuit breaker + retry:

```java
@CircuitBreaker(name = "authService", fallbackMethod = "fallback")
@Retry(name = "authService")
public AuthResponse validateToken(String token) { ... }
```

### Idempotency

All mutating endpoints must accept and honor `Idempotency-Key` header (see `docs/IDEMPOTENCY.md`).

## Event Logging Pattern

Use a Spring `HandlerInterceptor` or a servlet `Filter` for cross-cutting request logging. Log request method, path, status, and duration at the filter boundary. Attach trace ID to MDC in the same filter.

For event-specific auditing, use the structured logging library's (SLF4J) MDC context to add domain-specific fields per request. Avoid an AOP-based annotation framework — a single filter is simpler and covers all endpoints uniformly.

## Repository Patterns

### Interface + Implementation (composition)

Define an interface first, implement it directly. Avoid abstract repository base classes when the logic is simple:

```java
public interface UserSessionRepository {
    Optional<UserSession> findBySessionId(String sessionId);
    void save(UserSession session);
    void delete(String sessionId);
}

@Component
public class RedisUserSessionRepository implements UserSessionRepository {
    private final RedisTemplate<String, byte[]> redis;
    private final CryptoService crypto;

    public RedisUserSessionRepository(RedisTemplate<String, byte[]> redis, CryptoService crypto) {
        this.redis = redis;
        this.crypto = crypto;
    }

    @Override
    public Optional<UserSession> findBySessionId(String sessionId) { ... }
    @Override
    public void save(UserSession session) { ... }
    @Override
    public void delete(String sessionId) { ... }
}
```

A shared abstract base class (template method) is acceptable when multiple implementations share significant boilerplate, but start with plain interfaces + composition.

## Feign Client Pattern

```java
@FeignClient(name = "authorization-service", url = "${services.authorization.url}")
public interface AuthorizationClient {
    @PostMapping("/v1/authorize")
    AuthorizationResponse authorize(@RequestBody AuthorizationRequest request);
}
```

Or using the FeignClientFactory:

```java
AuthorizationClient client = feignClientFactory.createClient(
    AuthorizationClient.class,
    BaseFeignConfig.DEFAULT
);
```

Available client types:
- `DEFAULT` — sync with trace ID propagation.
- `SERVICE_AUTHENTICATED` — sync with trace ID + service-user access token.
- `BASIC_ASYNC` — async with static trace ID.
- `ASYNC_SERVICE_AUTHENTICATED` — async with static trace ID + access token.

## Saga & Outbox CI Gates

ArchUnit rules run automatically in CI when `SAGA_DETECTED=true`. Merge blocked on violation.

**Setup:** merge `ci/templates/archunit/pom-fragment.xml` into the child project POM to wire the ArchUnit test runner.

**`SagaArchRules.java` enforces:**
- Every `@SagaHandler` class has a compensation method (`*Compensate`, `compensate*`, `rollback*`, `undo*`).
- `@SagaHandler` classes are annotated `@Transactional`.
- Saga classes do not call broker APIs directly (no `KafkaProducer`, `RabbitTemplate`, `JmsTemplate`, etc.) — publish via an event gateway interface.
- Compensation methods are named idempotently (`*Compensate` / `compensate*` / `rollback*` / `undo*`).
- `@SagaHandler` classes declare a timeout (`@Timeout` or resilience4j `TimeLimiterConfig`).

**`OutboxArchRules.java` enforces:**
- All event publishing goes through `OutboxPublisher` (no direct broker calls from services).
- Outbox writes are `@Transactional` and co-located with the business write.
- Outbox consumers (`..outbox.consumer..` or `Outbox*`-dependent classes) have a deduplication store dependency.
- The relay component implements `OutboxRelay`.

**Test templates:** `ci/templates/tests/SagaIntegrationTestTemplate.java`, `ci/templates/tests/OutboxIntegrationTestTemplate.java`.

Read `docs/SAGA_PATTERN.md §CI Quality Gates` and `docs/OUTBOX_PATTERN.md §CI Quality Gates` before writing saga or outbox code.
