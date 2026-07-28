# Go Standards

## Build System

- **Go version**: 1.26.
- **Build tool**: Makefile, delegating to shared makefiles in `build/makefiles/`.

## Commands

| Command | What it does |
|---|---|
| `make setup` | Install dependencies, init submodules |
| `make build-deps` | Download Go module dependencies |
| `make build` | Build binary to `bin/` |
| `make test` | Run unit tests |
| `make test-cover-html` | Run tests + HTML coverage report |
| `make test-cover-junit` | Run tests + JUnit XML coverage report |
| `make generate-mocks` | Regenerate mocks via `gomockhandler` |
| `make generate-docs` | Generate Swagger docs |
| `make docker-run-scan` | Run ZAP security scan |
| `make run-e2e-tests` | Run Docker-based E2E tests |

## Project Structure

```
src/
├── main.go                    # Entry point
├── dependency_injection.go    # Wire all components
├── event_consumption.go       # Async consumer event loop
├── controllers/               # HTTP handlers (Gin)
├── services/                  # Business logic
├── repositories/              # Data access (SQL, NoSQL, Redis)
├── models/                    # Domain types / DTOs
├── middlewares/                # Gin middlewares (auth, trace ID)
├── resources/                 # HTTP clients to upstream services
├── consumers/                 # Async message consumers
├── publishers/                # Event bus publishers
├── helpers/                   # Crypto, token, Redis helpers
├── routes/                    # Route registration
├── configs/                   # Config parsing (env, YAML)
├── constants/                 # Enums and string constants
└── validators/                # Custom validation logic
```

## Dependency Injection

Manual DI in `dependency_injection.go`. No DI framework. Split into per-module factory functions as the app grows to avoid a god object:

```go
func BuildDependencies(ctx context.Context, cfg *config.Config) (*Dependencies, error) {
    repos := buildRepos(ctx, cfg)       // repo/repo.go
    services := buildServices(repos, cfg) // service/service.go
    controllers := buildControllers(services) // controller/controller.go
    return &Dependencies{Services: services, Controllers: controllers}, nil
}

func buildRepos(ctx context.Context, cfg *config.Config) *Repos {
    return &Repos{
        User: repository.NewUserRepository(dynamoClient, cfg),
        Session: repository.NewSessionRepository(redisClient, cfg),
    }
}
```

## Key Dependencies

```go
import (
    "github.com/gin-gonic/gin"          // Web framework
    "github.com/aws/aws-sdk-go-v2"      // AWS SDK
    "github.com/rs/zerolog"             // Structured logging
    "github.com/stretchr/testify"       // Test assertions
    "github.com/golang/mock"            // Mock generation
    "github.com/company/common-service/v2"  // Shared library
)
```

## Patterns

### Logging

```go
log := zerolog.Ctx(ctx)
log.Info().Str("userId", userId).Msg("Checking authorization")
log.Error().Err(err).Str("resource", resource).Msg("Authorization failed")
```

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
