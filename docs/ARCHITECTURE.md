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
│   ├── consumer/        # SQS/JMS message consumers
│   ├── publisher/       # SNS/SQS message publishers
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
├── event_consumption.go        # SQS consumer event loop
├── controllers/                # HTTP handlers (Gin handlers)
├── services/                   # Business logic
├── repositories/               # DynamoDB, Redis, PostgreSQL access
├── models/                     # Domain types
├── middlewares/                 # Gin middlewares
├── resources/                  # HTTP clients to upstream services (Resty)
├── consumers/                  # SQS consumer handlers
├── publishers/                 # SNS publisher helpers
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

## Microservice Patterns

### API Versioning

Use URL-based versioning: `/v1/`, `/v2/`. When an endpoint signature changes, create a new version. Do not modify existing versions.

### Inter-service Communication

- **Synchronous**: Use REST clients (Feign for Java, Resty for Go, Axios for JS). Each upstream service gets a dedicated client class/interface.
- **Asynchronous**: Use SQS for message consumption, SNS for event publishing.
- **Authentication between services**: Use service-user JWT tokens obtained via `ServiceUserAuthenticator` (self-authentication against auth service).

### Health Endpoints

Every service exposes:
- `GET /`: Simple ping ("OK")
- `GET /health`: Deep health check verifying all external dependencies (database, Redis, KMS, SQS, etc.)

Each dependency implements a health check (e.g., `AbstractHealthDependencyService`). The health endpoint aggregates results into a JSON response with per-dependency status.

### Exception Handling

Use a structured exception hierarchy. Each exception carries:
- HTTP status code
- Error code (machine-readable string)
- Description (human-readable)
- Error data map (optional)

A global `@ControllerAdvice` (Java) or error middleware (Go) catches these and returns a uniform JSON error response.

### Event Logging

Annotate controller methods with `@LogEvent` (Java). The aspect captures request context, publishes to configured log clients, and includes trace IDs in MDC for log tracing.

In Go, use a similar structured logging approach with zerolog and trace IDs propagated via context.

## Dependency Injection

- **Java**: Use Spring DI with constructor injection. Prefer `@Service`, `@Repository`, `@Component` stereotypes. Avoid `@Autowired` on fields.
- **Go**: Manual DI in `dependency_injection.go`. Wire all components in a single top-level function. No DI framework.
- **JS**: Pass dependencies explicitly via constructor or function arguments. Avoid global singletons (except well-defined ones like Redux store).
