# Coding Conventions

## Naming

| Element | Convention | Examples |
|---|---|---|
| Repository names | kebab-case | `authentication-service`, `nodepop-advanced` |
| Java packages | `com.openbank.<service>.<layer>` | `com.openbank.authservice.controller` |
| Go packages | `common_` prefix for shared code | `common_errors`, `common_services` |
| Classes / Types | PascalCase | `AuthenticationService`, `IdentityClaim` |
| Methods / Functions | camelCase | `getUserById()`, `hashPassword()` |
| Variables | camelCase | `userName`, `correlationId` |
| Constants / Enums | UPPER_SNAKE_CASE | `CHANNEL_WEB`, `STATUS_SUCCESS` |
| Database columns | snake_case | `user_name`, `created_at` |
| JSON fields | camelCase | `"userName":`, `"createdAt":` |
| Environment variables | UPPER_SNAKE_CASE | `SERVICE_NAME`, `AWS_REGION` |

## File Organization

- **One class per file** (Java).
- **One component per directory** with barrel export `index.js` (JS/TS).
- **Shared code** goes in `common_*` packages (Go) or `shared/` (JS).
- **Test files** mirror the source package structure.

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
- Structured logging through `EventLogger` framework: `initEvent()` → `addEventMessage()` → `flushSuccess()`/`flushFailure()`.
- Annotate controller methods with `@LogEvent` for automatic event logging.
- Correlation ID in MDC (`OPEN_BANK_CORRELATION_ID`). Propagate to downstream services via HTTP header.
- Log messages are capped at 1024 characters.
- Never log PII, secrets, or tokens.

### Go
- Use zerolog for structured logging: `log.Info().Str("key", "value").Msg("message")`.
- Correlation ID propagated via `context.Context`.
- Log at service method boundaries. Log input parameters and results.

### JavaScript
- Use structured logging library (pino, winston).
- Include correlation ID in every log entry.
- Avoid `console.log` in production code.

## Exception Handling

### Java

Use the exception hierarchy rooted at `SSSApplicationException`:

```
SSSApplicationException (abstract)
├── AuthenticationFailedException     → 401
├── AuthorizationFailedException      → 403
├── BusinessValidationException       → 202
├── ConcurrentModificationException   → 409
├── InternalServerErrorException      → 500
├── PreConditionFailedException       → 412
├── RequestValidationException        → 400
├── UnAuthorizedRequestException      → 401
├── UnprocessableEntityException      → 422
├── ThirdPartyServiceException        → depends
└── SSSDefaultException               → custom statusCode
```

Each exception carries:
- `statusCode` — HTTP status.
- `errorCode` — machine-readable string.
- `description` — human-readable message.
- `errorData` — optional map for additional context.
- `businessLogEvent` — for audit logging.

The `@ControllerAdvice` (order 0) catches all exceptions and returns a uniform JSON `ExceptionResponse`.

### Go

Define `ApplicationError` interface with `StatusCode()` and `Error() string`. Use a custom HTTP error handler middleware that converts errors to JSON responses.

### JavaScript

Use custom error classes extending `Error` with `statusCode` and `errorCode` fields. Express error middleware at the app boundary returns JSON errors.

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
