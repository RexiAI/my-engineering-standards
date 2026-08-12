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

The principles below are the mechanical standards this repo enforces on code.
`scripts/check-code-principles.sh` audits them across Java, Go, and JS/TS; the
spec pipeline's Verifier stage runs it as an independent gate. A FAIL is a
defect; a WARN is a review hint to verify before merging.

### KISS — Keep It Simple, Stupid

- **Methods under 20 lines**, classes under 200 lines, files under 500 lines.
  Split by responsibility, not by arbitrary size limits.
- **≤6 parameters per method.** More means the method is doing too much — bundle
  the arguments into a request object or split the method.
- **Low nesting.** Deeply nested conditionals (>6 brace levels) are a smell;
  extract methods or return early.

### DRY — Don't Repeat Yourself

- Same shape repeated across files is structural duplication, not just literal
  copy-paste. Consolidate only when the duplication shares a **reason to
  change** — two pieces that merely look similar for unrelated reasons are not
  duplicates.
- `scripts/check-code-principles.sh` flags identical 4-line blocks appearing in
  2+ places. Verify the "same reason to change" rule before consolidating.

### YAGNI — You Aren't Gonna Need It

- **No interface for one implementation.** An abstraction with exactly one
  concrete implementation is premature; add the interface when a second
  implementation exists or is demonstrably imminent.
- No empty method bodies in production code, no config knobs for values that
  never change, no speculative generality.

### SOLID

- **S**ingle Responsibility — one reason to change per class; a god file (>400
  lines, >15 methods) is a sign to split.
- **O**pen/Closed — open for extension, closed for modification. Large
  `switch`/`if-else` chains that dispatch on a type discriminator (≥4 cases)
  should be polymorphic dispatch or a lookup instead.
- **L**iskov Substitution — subtypes must be substitutable for their base
  without breaking callers. Heavy `instanceof`/type-test dispatch (≥3 in one
  file) usually means substitutability is broken.
- **I**nterface Segregation — clients shouldn't depend on methods they don't
  use. Split fat interfaces (>5 methods) by role.
- **D**ependency Inversion — depend on abstractions, and point dependencies
  inward. Domain/engine code must never import infrastructure (store,
  repository, persistence, DB clients). See `docs/ARCHITECTURE.md`.

### Base rules

- **Prefer composition over inheritance.** Use interfaces and delegation instead of abstract base classes. For tests, use plain `@BeforeEach` + helper methods instead of `AbstractBaseTestSuite` base classes.
- **Keep things small.** Classes under 200 lines, methods under 20 lines, files under 500 lines. Split by responsibility, not by arbitrary size limits.
- **Cyclomatic complexity ≤6 per method/function.** Enforced via PMD `CyclomaticComplexity`/`CognitiveComplexity` (Java), golangci `cyclop`/`gocognit` (Go), ESLint `complexity` (JS/TS) — see `language-specific/<lang>/`. Extract methods, invert conditionals, or replace nested branching with early returns rather than raise the threshold. `scripts/check-code-principles.sh` applies the same threshold as a language-agnostic heuristic.
- **Dependency rule.** Source code dependencies must point inward. Domain code never depends on infrastructure code. Controllers depend on services, services on repositories, never the reverse.
- **Generalize, don't special-case.** One mechanism should handle all similar cases. Avoid if/else chains that check exception types — use polymorphic dispatch or Result pattern matching.
- **Design interfaces to be deep.** A module's interface should be much simpler than its implementation. If a method just delegates with the same signature, it's a pass-through — remove it.
- **First do no harm with dependencies.** Each external dependency adds cognitive load and attack surface. Prefer stdlib, justify each dependency. Audit quarterly (see SECURITY.md).
- **Comment the why, not the what.** Code shows what a line does; a comment earns its place by explaining why it's not the obvious version — the incident it fixes, the second-order effect it avoids, the constraint that isn't visible in the diff. A one-line workaround with a multi-line comment explaining the trap it dodges is normal and correct; a comment restating the code below it is noise. If a line looks wrong at a glance but is intentional, that's exactly the line that needs the comment.

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
- Use the stdlib `log/slog` package for structured logging: `slog.Info("message", "key", "value")`. This supersedes any previous zerolog guidance — `slog` has been in the stdlib since Go 1.21, so it's the "prefer stdlib" default from §Design Principles rather than an added dependency. `zerolog` remains an acceptable choice for a project that already standardized on it; don't migrate a working project just to match this doc.
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
