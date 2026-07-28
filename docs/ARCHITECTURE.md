# Architecture Standards

## Layered Architecture

All services follow a layered pattern with strict dependency direction:

```
Controller (HTTP handlers)
    │
    ▼
Service (business logic)
    │
    ▼
Repository (data access)
    │
    ▼
External (database, cache, upstream services)
```

Layers may only depend on the layer directly below. Controllers never access repositories directly.

### Layer Responsibilities

**Controller layer:**
- Parse and validate HTTP request input.
- Call service methods for business logic.
- Return HTTP responses. Never contain business logic.

**Service layer:**
- Orchestrate business operations.
- Coordinate across multiple repositories or external clients.
- Apply domain logic and validation rules.
- Emit events / logs at method boundaries.

**Repository layer:**
- Abstract data access (database, cache, external API).
- Map between domain objects and persistence/DTO models.

## Project Structure

### Java (Spring Boot)

```
src/
├── main/java/com/<company>/<service>/
│   ├── Application.java
│   ├── config/          # @Configuration, @PropertySource, bean wiring
│   ├── controller/      # @RestController, request/response DTOs
│   ├── service/         # @Service, business logic
│   ├── repository/      # Data access (rdbms/, redis/, dynamodb/)
│   ├── model/           # Domain models / entities
│   ├── mapper/          # MapStruct mappers (DTO ↔ domain)
│   ├── resource/        # Feign/Retrofit HTTP clients to upstream services
│   ├── consumer/        # Async message consumers (SQS, RabbitMQ, etc.)
│   ├── publisher/       # Event/message bus publishers
│   ├── event/           # Event/Audit logger clients
│   ├── interceptor/     # Spring HandlerInterceptors, request-scoped containers
│   ├── resolver/        # Custom HandlerMethodArgumentResolvers
│   ├── validator/       # Custom bean validators
│   └── constant/        # Enums and constants
├── test/java/
├── integration-tests/java/
├── e2e-framework/java/
└── e2e/java/
```

### Go

```
src/
├── main.go                     # Entry point
├── dependency_injection.go     # Manual wiring of all components
├── event_consumption.go        # Async consumer event loop
├── controllers/                # HTTP handlers (Gin handlers)
├── services/                   # Business logic
├── repositories/               # Data access (DB, cache, key-value store)
├── models/                     # Domain types
├── middlewares/                 # Gin middlewares
├── resources/                  # HTTP clients to upstream services
├── consumers/                  # Async message consumer handlers
├── publishers/                 # Event bus publisher helpers
├── helpers/                    # Crypto, auth token, Redis helpers
├── routes/                     # Route definitions
├── configs/                    # Env parsing, YAML config loaders
└── constants/                  # Enums and string constants
```

### JavaScript / TypeScript (Node.js)

```
src/
├── api/                    # Axios instance + interceptors + endpoint modules
│   ├── client.js
│   ├── auth.js
│   ├── adverts.js
│   └── index.js            # Barrel export
├── components/             # React components organized by domain
│   ├── auth/
│   │   ├── LoginPage/
│   │   │   ├── LoginPage.js
│   │   │   └── index.js
│   │   └── index.js
│   └── shared/             # Reusable UI components
├── hooks/                  # Custom React hooks (useForm, etc.)
├── store/                  # Redux store, actions, reducers, selectors
├── utils/                  # Utilities (storage helpers, formatters)
├── translations/           # i18n configuration and locale files
├── styles/                 # Global styles
├── App.js                  # Root component
└── index.js                # Entry point
```

## Module Design Checklist (Ousterhout)

Every module (class, service, method) must satisfy:

1. **Simple Interface**: The interface should be much simpler than its implementation
2. **Information Hiding**: Internal complexity is encapsulated, not leaked
3. **One Responsibility**: Change the module for one reason
4. **Design Twice**: Before committing to a design, consider at least one alternative
5. **Depth Over Width**: A module should do more "inside" than it exposes via its interface
6. **No Pass-Through Methods**: If a method just delegates to another with the same signature, both are shallow — inline or restructure

### Complexity Budget

Maximum cognitive load per module:
- One class: 200 lines
- One method: 20 lines
- One file: 500 lines
- Max dependencies (incoming + outgoing): 15
- Max nesting: 3 levels deep

## Architecture Decision Records

All architectural decisions must be recorded as ADRs (see `templates/ADR.md`). Required for:

- Adding a new external dependency (database, message queue, cache)
- Changing the data model or schema
- Choosing between alternative technologies (SQL vs NoSQL, REST vs gRPC)
- Adding or removing a service boundary
- Cross-service API changes

Each ADR must include: alternatives considered, decision rationale, consequences, and compliance enforcement.

## Observability Integration

Every service layer integrates with observability:

```
Controller → Traces inbound request, records HTTP metrics
Service    → Traces business logic, logs method boundaries with trace ID
Repository → Traces queries, records DB latency metrics
External   → Traces downstream calls, records circuit breaker state
```

Service implementation must use OpenTelemetry SDKs (not vendor-specific tracers). See `docs/OBSERVABILITY.md`.

## Microservice Patterns

### API Versioning

Use URL-based versioning: `/v1/`, `/v2/`. When an endpoint signature changes, create a new version. Do not modify existing versions. Verify API compatibility automatically in CI (see `docs/SCHEMA_EVOLUTION.md`).

### Inter-service Communication

- **Synchronous**: Use REST clients (Feign for Java, Go `net/http`, Axios for JS). Each upstream service gets a dedicated client class/interface.
- **Asynchronous**: Use message queues for event consumption (SQS, RabbitMQ) and event buses for publishing (SNS, EventBridge, Kafka).
- **Authentication between services**: Use service-to-service JWT tokens obtained via a self-authentication mechanism against the auth service.

### Health Endpoints

Every service exposes:
- `GET /`: Simple ping ("OK")
- `GET /health`: Deep health check verifying all external dependencies (database, cache, messaging, key management, etc.)

Each dependency implements a health check (e.g., `AbstractHealthDependencyService`). The health endpoint aggregates results into a JSON response with per-dependency status.

### Error Handling (Ousterhout: Define Errors Out of Existence)

Define errors out of existence. Prefer domain Result types over exceptions for expected failure modes:

```java
// Instead of: throw new BusinessValidationException("email taken")
// Prefer:
public Result<User, Error> createUser(CreateUserRequest request) {
    if (emailExists(request.email())) return Result.error(Error.EmailTaken);
    return Result.ok(repository.save(request.toUser()));
}
```

Reserve exceptions for truly exceptional/unrecoverable conditions (infrastructure failure, programming errors). Expected failures (validation, not found, conflict) are return values, not control flow.

A global `@ControllerAdvice` (Java) or error middleware (Go) catches truly exceptional cases and returns a uniform JSON error response. Expected failures from Result types are handled at the controller boundary and return appropriate HTTP status codes.

### Event Logging

Log at controller boundaries using a filter or interceptor. Capture request context, publish to configured log targets, and include trace IDs in MDC for log tracing.

In Go, use a similar structured logging approach with zerolog and trace IDs propagated via context.

See `docs/OBSERVABILITY.md` for full observability requirements (tracing, metrics, alerting).

## Dependency Injection

- **Java**: Use Spring DI with constructor injection. Prefer `@Service`, `@Repository`, `@Component` stereotypes. Avoid `@Autowired` on fields.
- **Go**: Manual DI in `dependency_injection.go`. Wire all components in a single top-level function. No DI framework.
- **JS**: Pass dependencies explicitly via constructor or function arguments. Avoid global singletons (except well-defined ones like Redux store).

## Resilience Integration

Every external dependency must be protected:

| Protection | Pattern | See |
|-----------|---------|-----|
| Transient failures | Retry with exponential backoff | RESILIENCE.md |
| Cascading failures | Circuit breaker | RESILIENCE.md |
| Resource exhaustion | Bulkhead, timeout | RESILIENCE.md |
| Duplicate requests | Idempotency key | IDEMPOTENCY.md |
| Reliable publishing | Transactional outbox | OUTBOX_PATTERN.md |
