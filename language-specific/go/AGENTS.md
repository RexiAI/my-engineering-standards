# Go Standards

## Build System

- **Go version**: resolved from `go.mod`'s `go` line (and `toolchain` line if pinning a specific patch) — never hardcode a version in CI config or a Dockerfile separately from the module file. See docs/CI_CD.md §Toolchain Versions.
- **Build tool**: Makefile. `make ci-fast` (vet + lint + test, no external services) → `make ci` (adds build + anything needing only local tooling) → `make ci-full` (adds Docker-dependent E2E) is the standard ladder — each rung's infrastructure requirement should be documented next to its target. The same targets are what CI and git hooks both call; never duplicate a command list in YAML that a Makefile target already expresses.

## Commands

| Command | What it does |
|---|---|
| `make ci-fast` | `vet`, `lint`, `test` — no external services required |
| `make ci` | Everything `ci-fast` does, plus build |
| `make ci-full` | Everything `ci` does, plus Docker-dependent E2E |
| `make build` | Build binary to `bin/` |
| `make test` | `go test -race -shuffle=on -count=1 ./...` — race detector, randomized test order (catches inter-test coupling), disabled test cache (`-count=1`) so a stale pass can't hide a real failure |
| `make test-cover-html` | Run tests + HTML coverage report |
| `make test-cover-junit` | Run tests + JUnit XML coverage report |
| `make hooks-install` | `git config core.hooksPath .githooks` — one-time per clone, see docs/GIT_WORKFLOW.md §Git Hooks |
| `make generate-mocks` | Regenerate mocks, only if the project has adopted `gomockhandler` (optional — see docs/TESTING.md §Unit Tests) |
| `make generate-docs` | Generate Swagger docs |
| `make docker-run-scan` | Run ZAP security scan (`production`-tier, see docs/CONFORMANCE_TIERS.md) |
| `make run-e2e-tests` | Run Docker-based E2E tests |

## Project Structure

```
cmd/
└── server/
    └── main.go                # Entry point, route registration, dependency wiring
internal/
├── dependency_injection.go    # Wire all components (or split into per-module factory
│                               # functions as the app grows, to avoid a god object)
├── routes/                    # Route registration
├── services/                  # Business logic
├── store/                     # Data access (SQL, NoSQL, Redis) — see §Repository below
├── models/                    # Domain types / DTOs
├── middleware/                # Gin/http middlewares (auth, request ID)
├── engine/                    # Domain-specific computation (pricing, classification, etc.)
└── config/                    # Config parsing (env, YAML)
```

`internal/` gives compiler-enforced encapsulation that a plain `src/` tree can't — anything under `internal/` is unimportable from outside the module, so the boundary is checked by the Go toolchain, not just by convention. `cmd/<binary-name>/main.go` is the standard layout for a Go module that produces one or more binaries; use `cmd/<name>/` per binary if the module produces more than one.

## Dependency Injection

Manual DI in `internal/dependency_injection.go` (or wired directly in `cmd/server/main.go` for a small service — extract into its own file once wiring grows past a screenful). No DI framework. Split into per-module factory functions as the app grows to avoid a god object:

```go
func BuildDependencies(ctx context.Context, cfg *config.Config) (*Dependencies, error) {
    store := buildStore(ctx, cfg)          // store/store.go
    services := buildServices(store, cfg)  // service/service.go
    routes := buildRoutes(services)        // routes/routes.go
    return &Dependencies{Services: services, Routes: routes}, nil
}

func buildStore(ctx context.Context, cfg *config.Config) *Store {
    return &Store{
        Users:    store.NewUserStore(db, cfg),
        Sessions: store.NewSessionStore(redisClient, cfg),
    }
}
```

## Key Dependencies

```go
import (
    "github.com/gin-gonic/gin"          // Web framework
    "github.com/aws/aws-sdk-go-v2"      // AWS SDK
    "log/slog"                          // Structured logging (stdlib, see docs/CODING_CONVENTIONS.md §Logging)
    "github.com/company/common-service/v2"  // Shared library
)
```

`testify` and `github.com/golang/mock`/`gomockhandler` are optional additions, not defaults — see docs/TESTING.md §Unit Tests. Add either only when the stdlib `testing` package is genuinely insufficient for the project's test complexity.

## Patterns

### Logging

```go
slog.Info("checking authorization", "userId", userId)
slog.Error("authorization failed", "error", err, "resource", resource)
```

For a request-scoped logger with common fields attached, build one from `context.Context` via `slog.With(...)` and pass it down, or attach fields per call site — either is fine; don't build a bespoke wrapper around `slog` unless the project needs something `slog.Handler` genuinely can't express.

### Trace ID

Propagate via `context.Context`. Extract from incoming `traceparent` header (W3C Trace Context), forward to downstream services.

### REST Client (stdlib)

Prefer Go's `net/http` standard library for simple cases. The stdlib is sufficient for most REST clients:

```go
req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
req.Header.Set("Authorization", "Bearer "+token)
resp, err := http.DefaultClient.Do(req)
if err != nil { return nil, err }
defer resp.Body.Close()
body, _ := io.ReadAll(resp.Body)
```

For HTTP clients that need retries, metrics, or circuit breakers, wrap the stdlib client with a thin helper layer. Avoid framework-specific HTTP clients unless they are shared across the entire codebase via a common library.

### Repository

```go
type UserRepository interface {
    GetUser(ctx context.Context, userID string) (*User, error)
    SaveUser(ctx context.Context, user *User) error
}

type userRepository struct {
    db    *dynamodb.Client
    table string
    crypto *CryptoHelper
}
```

### Error Handling: Result Types

Prefer sentinel errors for expected failures. Reserve panics for programming errors.

```go
// Expected failures: sentinel errors
var (
    ErrEmailTaken   = errors.New("email taken")
    ErrInvalidEmail = errors.New("invalid email")
    ErrUserNotFound = errors.New("user not found")
)

// Service returns (result, error) for expected failures
func (s *UserService) CreateUser(ctx context.Context, req CreateUserRequest) (*User, error) {
    exists, err := s.emailRepo.Exists(ctx, req.Email)
    if err != nil {
        return nil, fmt.Errorf("check email: %w", err) // infrastructure = wrap
    }
    if exists {
        return nil, ErrEmailTaken // expected = sentinel
    }
    return s.userRepo.Save(ctx, req.ToUser())
}

// Middleware translates errors to HTTP
func ErrorMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Next()
        if len(c.Errors) == 0 { return }
        err := c.Errors.Last().Err
        switch {
        case errors.Is(err, ErrEmailTaken):
            c.JSON(409, gin.H{"error": err.Error(), "code": "EMAIL_TAKEN"})
        case errors.Is(err, ErrUserNotFound):
            c.JSON(404, gin.H{"error": err.Error(), "code": "NOT_FOUND"})
        default:
            c.JSON(500, gin.H{"error": "internal server error"})
        }
    }
}
```

### Resilience

Every external HTTP client must include retry + circuit breaker:

```go
type ResilientClient struct {
    client *http.Client
    cb     *breaker.CircuitBreaker
}

func (c *ResilientClient) Do(req *http.Request) (*http.Response, error) {
    var resp *http.Response
    err := c.cb.Execute(func() (interface{}, error) {
        return c.client.Do(req)
    })
    if err != nil {
        return nil, err
    }
    return resp, nil
}
```

### Health Endpoint

```go
r.GET("/health", func(c *gin.Context) {
    deps := map[string]string{
        "cache":     checkRedis(),
        "database":  checkDatabase(),
    }
    c.JSON(200, deps)
})
```

## Saga & Outbox CI Gates

`ci/templates/go-saga-lint.go` runs via `go run` in CI when `SAGA_DETECTED=true`. Merge blocked on violation.

**AST checks enforced:**
- Every `*SagaHandler` function must have a sibling compensation function: `*Compensate`, `Rollback*`, `rollback*`, `On*Failed`, or `on*Failed`.
- Saga handler files must use `context.WithTimeout` or `context.WithDeadline` (not just passed through — must be called).
- Saga files must not call broker APIs directly: no `kafka.NewProducer`, `nats.Publish`, `amqp.Channel`, etc. Publish via an interface.

**Shell gates also run** (from `scripts/`):
- `check-saga-timeouts.sh` — per-file `context.WithTimeout` check.
- `check-saga-tests.sh` — integration test files with compensation scenarios required.
- `lint-outbox-schema.sh` — outbox migration in `db/migrations/` must have required columns, partial index, and cleanup.
- `check-outbox-relay.sh` — relay component and consumer dedup logic must exist.

**Test templates:** `ci/templates/tests/saga_integration_test.go`, `ci/templates/tests/outbox_integration_test.go`.

Read `docs/SAGA_PATTERN.md §CI Quality Gates` and `docs/OUTBOX_PATTERN.md §CI Quality Gates` before writing saga or outbox code.
