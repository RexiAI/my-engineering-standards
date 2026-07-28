# Coding Conventions

## Naming

| Element | Convention | Examples |
|---|---|---|
| Repository names | kebab-case | `authentication-service`, `nodepop-advanced` |
| Java packages | `com.<company>.<service>.<layer>` | `com.company.authservice.controller` |
| Go packages | `common_` prefix for shared code | `common_errors`, `common_services` |
| Classes / Types | PascalCase | `AuthenticationService`, `IdentityClaim` |
| Methods / Functions | camelCase | `getUserById()`, `hashPassword()` |
| Variables | camelCase | `userName`, `traceId` |
| Constants / Enums | UPPER_SNAKE_CASE | `CHANNEL_WEB`, `STATUS_SUCCESS` |
| Database columns | snake_case | `user_name`, `created_at` |
| JSON fields | camelCase | `"userName":`, `"createdAt":` |
| Environment variables | UPPER_SNAKE_CASE | `SERVICE_NAME`, `AWS_REGION` |

## File Organization

- **One class per file** (Java).
- **One component per directory** with barrel export `index.js` (JS/TS).
- **Shared code** goes in `common_*` packages (Go) or `shared/` (JS).
- **Test files** mirror the source package structure.

## Design Principles

- **Prefer composition over inheritance.** Use interfaces and delegation instead of abstract base classes. For tests, use plain `@BeforeEach` + helper methods instead of `AbstractBaseTestSuite` base classes.
- **Keep things small.** Classes under 200 lines, methods under 20 lines, files under 500 lines. Split by responsibility, not by arbitrary size limits.
- **Dependency rule.** Source code dependencies must point inward. Domain code never depends on infrastructure code. Controllers depend on services, services on repositories, never the reverse.
- **Generalize, don't special-case.** One mechanism should handle all similar cases. Avoid if/else chains that check exception types — use polymorphic dispatch or Result pattern matching.
- **Design interfaces to be deep.** A module's interface should be much simpler than its implementation. If a method just delegates with the same signature, it's a pass-through — remove it.
- **First do no harm with dependencies.** Each external dependency adds cognitive load and attack surface. Prefer stdlib, justify each dependency. Audit quarterly (see SECURITY.md).

## Error Handling Philosophy

Prefer domain Result types for expected failure modes. Reserve exceptions for truly exceptional conditions (infrastructure failure, programming errors).

### Result Type Pattern

```java
// Expected failures are return values, not control flow
public sealed interface Result<T, E> {
    record Ok<T, E>(T value) implements Result<T, E> {}
    record Error<T, E>(E error) implements Result<T, E> {}
}

public enum CreateUserError {
    EMAIL_TAKEN,
    INVALID_EMAIL,
}
```

```go
// Go: Use Result[T, E] or (T, error) where error is a domain type
type CreateUserResult struct {
    User *User
    Err  *CreateUserError
}

type CreateUserError string
const (
    ErrEmailTaken    CreateUserError = "EMAIL_TAKEN"
    ErrInvalidEmail  CreateUserError = "INVALID_EMAIL"
)
```

```ts
// TypeScript: discriminated union
type CreateUserResult =
    | { ok: true; user: User }
    | { ok: false; error: CreateUserError }
```

### When to Use Which

| Scenario | Use |
|----------|-----|
| Caller expects this failure (validation, not found, conflict) | Result type |
| Infrastructure failure (DB down, network timeout) | Exception → circuit breaker |
| Programming error (null pointer, illegal argument) | Exception → fix the code |
| Expected retry scenario (rate limit, conflict) | Result type + retry |

## Formatting

### Java
- Google Java Format via Spotless Maven Plugin.
- 4-space indentation.
- 100-character line width.
- No trailing whitespace.
- One blank line between import groups (static, java, javax, org, com).

### Go
- `gofmt` standard formatting enforced by `golangci-lint`.
- Tab indentation.
- No unused imports or variables.

### JavaScript / TypeScript
- Prettier formatting with:
  - Single quotes.
  - Trailing commas (es5).
  - 100-character line width.
  - 2-space indentation.

## Logging

### Java
- Use SLF4J with `@Slf4j` Lombok annotation.
- Log at method boundaries: input parameters and results. Use a `HandlerInterceptor` or filter for cross-cutting request logging instead of an AOP-based event framework.
- Trace ID in MDC. Propagate via `traceparent` header (W3C Trace Context).
- Log messages are capped at 1024 characters.
- Never log PII, secrets, or tokens.

### Go
- Use zerolog for structured logging: `log.Info().Str("key", "value").Msg("message")`.
- Trace ID propagated via `context.Context`.
- Log at service method boundaries. Log input parameters and results.

### JavaScript
- Use structured logging library (pino, winston).
- Include trace ID in every log entry.
- Avoid `console.log` in production code.

## Exception Handling

### Philosophy

Exceptions are for exceptional conditions only. Expected failures — validation errors, resource not found, duplicate key — are return values via Result types, not exceptions.

Exceptions map to Result.Error values at the service boundary. The controller translates the error value into the appropriate HTTP response.

### Java

Reserve exceptions for truly exceptional conditions. Expected failures use a closed Result type:

```java
// Service returns result, not exception
public Result<User, CreateUserError> createUser(CreateUserRequest request) {
    if (emailExists(request.email())) return Result.error(CreateUserError.EMAIL_TAKEN);
    return Result.ok(repository.save(request.toUser()));
}

// Controller maps result to HTTP response
@PostMapping("/v1/users")
public ResponseEntity<?> createUser(@Valid @RequestBody CreateUserRequest request) {
    return switch (userService.createUser(request)) {
        case Result.Ok(var user) -> ResponseEntity.status(201).body(user);
        case Result.Error(var err) -> switch (err) {
            case EMAIL_TAKEN -> ResponseEntity.status(409).body(Map.of("error", "email taken"));
            case INVALID_EMAIL -> ResponseEntity.status(422).body(Map.of("error", "invalid email"));
        };
    };
}
```

The `@ControllerAdvice` catches only truly exceptional conditions (infrastructure failures, programming errors) and returns uniform JSON. Not used for expected business logic failures.

### Go

Define `ApplicationError` interface with `StatusCode()` and `Error() string`. Use a custom HTTP error handler middleware that converts errors to JSON responses. Prefer sentinel errors for expected failures:

```go
var (
    ErrEmailTaken   = errors.New("email taken")
    ErrInvalidEmail = errors.New("invalid email")
)
```

### JavaScript

Use NestJS global exception filter with custom exception classes extending `HttpException`. For expected failures, use Result types rather than throwing. Single `@Catch()` filter catches only truly exceptional conditions.

## Imports Ordering

### Java
```
// static imports
// java.*
// javax.*
// org.*
// com.*
// Blank line between groups
```

### Go
Standard Go imports: stdlib first, third-party, local, blank line between groups.

### JavaScript
Organized imports: `react`/framework → libraries → local modules → styles.
