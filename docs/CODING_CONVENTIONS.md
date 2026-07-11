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

- **Prefer composition over inheritance.** Use interfaces and delegation instead of abstract base classes. Inheritance is acceptable for exception hierarchies and stable framework extension points (template method). For tests, use plain `@BeforeEach` + helper methods instead of `AbstractBaseTestSuite` base classes.
- **Keep things small.** Classes under 200 lines, methods under 20 lines, files under 500 lines. Split by responsibility, not by arbitrary size limits.
- **Dependency rule.** Source code dependencies must point inward. Domain code never depends on infrastructure code. Controllers depend on services, services on repositories, never the reverse.

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

### Java

Use the exception hierarchy rooted at `ApplicationException`:

```
ApplicationException (abstract)
├── AuthenticationException           → 401
├── BusinessValidationException       → 202
├── NotFoundException                 → 404
└── InternalServerException           → 500
```

Each exception carries:
- `statusCode` — HTTP status.
- `errorCode` — machine-readable string.
- `description` — human-readable message.
- `errorData` — optional map for additional context.

The `@ControllerAdvice` (order 0) catches all exceptions and returns a uniform JSON error response.

### Go

Define `ApplicationError` interface with `StatusCode()` and `Error() string`. Use a custom HTTP error handler middleware that converts errors to JSON responses. Keep the interface small — only error codes that callers need to distinguish.

### JavaScript

Use NestJS global exception filter with custom exception classes extending `HttpException`. Single `@Catch()` filter at the app boundary returns structured JSON errors. Use `class-validator` DTOs for input validation via `ValidationPipe`.

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
