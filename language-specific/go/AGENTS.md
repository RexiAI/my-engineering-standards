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
├── event_consumption.go       # SQS consumer event loop
├── controllers/               # HTTP handlers (Gin)
├── services/                  # Business logic
├── repositories/              # Data access (DynamoDB, Redis, PostgreSQL)
├── models/                    # Domain types / DTOs
├── middlewares/                # Gin middlewares (auth, trace ID)
├── resources/                 # HTTP clients to upstream services
├── consumers/                 # SQS message consumers
├── publishers/                # SNS message publishers
├── helpers/                   # Crypto, token, Redis helpers
├── routes/                    # Route registration
├── configs/                   # Config parsing (env, YAML)
├── constants/                 # Enums and string constants
└── validators/                # Custom validation logic
```

## Dependency Injection

Manual DI in `dependency_injection.go`. No DI framework.

```go
func BuildDependencies(ctx context.Context, cfg *config.Config) (*Dependencies, error) {
    awsConfig := loadAWSConfig(ctx)
    dynamoClient := dynamodb.NewFromConfig(awsConfig)
    redisClient := connectRedis(ctx, cfg)

    userRepo := repository.NewUserRepository(dynamoClient, cfg)
    sessionRepo := repository.NewSessionRepository(redisClient, cfg)
    authService := service.NewAuthService(userRepo, sessionRepo, cfg)
    authController := controller.NewAuthController(authService)

    return &Dependencies{
        Controllers: []Controller{authController},
    }, nil
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

### REST Client (common-service)

```go
client := common_http_client.NewRestyClient()
resp, err := client.R().
    SetHeader("Authorization", "Bearer "+token).
    SetResult(&targetResponse).
    Post(url)
```

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

### Error Handling

```go
// Define custom error interface
type ApplicationError interface {
    StatusCode() int
    Error() string
}

// Middleware catches errors and returns JSON
func ErrorMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Next()
        if len(c.Errors) > 0 {
            err := c.Errors.Last().Err
            if appErr, ok := err.(ApplicationError); ok {
                c.JSON(appErr.StatusCode(), gin.H{"error": appErr.Error()})
            } else {
                c.JSON(500, gin.H{"error": "internal server error"})
            }
        }
    }
}
```

### Health Endpoint

```go
r.GET("/health", func(c *gin.Context) {
    deps := map[string]string{
        "redis":     checkRedis(),
        "dynamodb":  checkDynamoDB(),
    }
    c.JSON(200, deps)
})
```
