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
| `mvn clean install -Pservice-tests` | Run Docker-based service (E2E) tests |
| `mvn spotless:check` | Check code formatting |
| `mvn spotless:apply` | Fix code formatting |
| `mvn pmd:pmd pmd:cpd` | Run PMD + copy-paste detection |
| `mvn spotbugs:spotbugs` | Run SpotBugs + FindSecBugs |

## Key Dependencies

Managed by the parent POM. Common starters and libraries:

```xml
<dependencies>
  <dependency>com.company:sss-application-starter</dependency>
  <dependency>com.company.sss:sss-commons</dependency>
  <dependency>com.company.sss:sss-feign-starter</dependency>
  <dependency>org.springframework.boot:spring-boot-starter-web</dependency>
  <dependency>org.springframework.boot:spring-boot-starter-actuator</dependency>
  <dependency>org.springframework.boot:spring-boot-starter-data-jpa</dependency>
  <dependency>org.springframework.boot:spring-boot-starter-data-redis</dependency>
  <dependency>org.springframework.boot:spring-boot-starter-validation</dependency>
  <dependency>org.springframework.boot:spring-boot-starter-undertow</dependency>  <!-- instead of Tomcat -->
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
@SssServiceApplication(exclude = {DataSourceAutoConfiguration.class})
public class Application {
    public static void main(final String[] args) {
        SssApplication.run(Application.class, args);
    }
}
```

### Common Container (Request-scoped)

```java
@Component
@RequestScope
public class CommonContainer extends BaseCommonContainer {
    @Override
    public String getProgressId() { ... }
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

## Event Logging Pattern

Annotate controller methods with `@LogEvent`:

```java
@LogEvent(event = EventType.USER_LOGIN)
@PostMapping("/v1/login")
public ResponseEntity<LoginResponse> login(@RequestBody @Valid LoginRequest request) { ... }
```

Configure event logger clients in `application.yml`:

```yaml
event-logger:
  async: true
  clients: LOG_INFO, LOG_RESULT
  event-driver:
    bus: ${EVENT_DRIVER_BUS_NAME}
```

## Repository Patterns

### Redis Repository

```java
@Component
public class UserSessionRepository extends AbstractRedisRepository<UserSession, String> {
    @Override
    protected RedisData mapToRedis(UserSession domain) { ... }
    @Override
    protected UserSession mapToDomain(RedisData data) { ... }
    @Override
    protected String getKey(UserSession domain) { return domain.getSessionId(); }
}
```

### DynamoDB Repository

```java
@Component
public class UserCredentialsRepository extends AbstractDynamoRepository<UserCredentials, String> {
    @Override
    protected UserCredentialsDynamoDto toDynamoDto(UserCredentials domain) { ... }
    @Override
    protected UserCredentials toDomain(UserCredentialsDynamoDto dto) { ... }
    ...
}
```

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
- `DEFAULT` — sync with correlation ID propagation.
- `SERVICE_AUTHENTICATED` — sync with correlation ID + service-user access token.
- `BASIC_ASYNC` — async with static correlation ID.
- `ASYNC_SERVICE_AUTHENTICATED` — async with static correlation ID + access token.
