# Resilience Standards

## Philosophy

Every external dependency will fail. Design for failure, not for perfect uptime.

From Kleppmann: "Fault-tolerant systems rely on redundancy, isolation, and graceful degradation."

## Circuit Breaker

Every HTTP client, message consumer, and database access must be protected by a circuit breaker.

### States

| State | Behavior |
|-------|----------|
| CLOSED | Requests flow normally. Failure count resets after success. |
| OPEN | Requests fail fast (no attempt). Transitions to HALF-OPEN after timeout. |
| HALF-OPEN | Limited test requests. Success → CLOSED. Failure → OPEN. |

### Thresholds

- Failure threshold: 5 consecutive failures within 10s sliding window
- Open duration: 30s
- Half-open max requests: 3
- Timeout: 2s per request (shorter than external timeout)

### Implementation

```java
// Java (Resilience4j)
@CircuitBreaker(name = "authService", fallbackMethod = "fallback")
public AuthResponse validateToken(String token) { ... }

public AuthResponse fallback(String token, Throwable t) {
    log.warn("Auth service unavailable, returning cached response");
    return cache.get(token);
}
```

```go
// Go (go-breaker)
var cb = breaker.NewCircuitBreaker(breaker.Settings{
    Name:        "auth-service",
    MaxRequests: 3,
    Interval:    10 * time.Second,
    Timeout:     30 * time.Second,
    ReadyToTrip: func(counts breaker.Counts) bool {
        return counts.ConsecutiveFailures > 5
    },
})
```

```ts
// TypeScript (opossum)
const breaker = new CircuitBreaker(authClient.validateToken, {
    timeout: 2000,
    errorThresholdPercentage: 50,
    resetTimeout: 30000,
    volumeThreshold: 5,
})
```

## Retry with Exponential Backoff

Not all failures warrant a circuit breaker trip. Transient failures (network blips, connection pool exhaustion) should be retried.

### When to Retry

| Status | Action |
|--------|--------|
| 5xx (server error) | Retry with backoff |
| 429 (rate limit) | Retry with backoff + `Retry-After` header |
| 4xx (client error) | Never retry — fail fast |
| Connection timeout | Retry |
| DNS resolution failure | Retry |

### Backoff Formula

```
delay = baseDelay * multiplier^attempt + jitter(0, jitterRange)

baseDelay = 100ms
multiplier = 2
maxDelay = 10s
maxAttempts = 3
jitter = random(0, baseDelay)
```

### Implementation

```java
@Retry(name = "dbQuery", fallbackMethod = "queryFallback")
public List<User> queryUsers(String filter) { ... }
```

```go
func retry(operation func() error) error {
    b := backoff.NewExponentialBackOff()
    b.MaxElapsedTime = 10 * time.Second
    return backoff.Retry(operation, backoff.WithContext(b, ctx))
}
```

```ts
async function retry<T>(fn: () => Promise<T>, retries = 3): Promise<T> {
    for (let i = 0; i < retries; i++) {
        try { return await fn() }
        catch (e) { if (i === retries - 1) throw e; await delay(100 * 2 ** i) }
    }
}
```

## Timeout

Every external call must have a timeout shorter than the caller's timeout.

| Operation | Default Timeout |
|-----------|----------------|
| HTTP request (internal) | 2s |
| HTTP request (external/3rd party) | 5s |
| Database query | 5s |
| Cache read | 500ms |
| Cache write | 1s |
| Message publish | 3s |

## Bulkhead

Isolate thread pools per dependency to prevent one failing dependency from consuming all resources.

### Strategy

- Separate connection pools per external service
- Bounded queues: max 10 pending requests per dependency
- Reject new requests when queue full (fail fast, don't block)

```java
@Bulkhead(name = "authService", type = ThreadPoolBulkhead.class)
```

```go
// Worker pool pattern
pool := workerpool.New(5, workerpool.WithMaxQueueSize(10))
```

## Rate Limiting

Protect downstream services from traffic spikes.

| Pattern | Use Case |
|---------|----------|
| Token bucket | Smooth bursty traffic (default) |
| Leaky bucket | Strict rate enforcement for paid APIs |
| Sliding window | Per-user rate limiting |

### Default Limits

```
Service-to-service: 1000 req/s per client
Per-user: 100 req/s
Per-IP (public): 10 req/s
```

## Graceful Shutdown

All services must handle SIGTERM gracefully:

1. Stop accepting new requests
2. Drain in-flight requests (max 30s)
3. Close database/cache connections
4. Flush pending logs/metrics
5. Exit with status 0

## Health Check Aggregation

The `/health` endpoint must report:

```json
{
    "status": "UP",
    "checks": [
        { "name": "database", "status": "UP", "details": { "latency": "5ms" } },
        { "name": "redis", "status": "UP" },
        { "name": "auth-service", "status": "DEGRADED", "details": { "circuitBreaker": "OPEN" } }
    ]
}
```

Status propagation: UP (all OK) → DEGRADED (non-critical dependency down) → DOWN (critical dependency down).

## See Also

- `docs/IDEMPOTENCY.md` — deduplication for retried requests
- `docs/OBSERVABILITY.md` — metrics, tracing, alerting for failures
- `docs/DEPLOYMENT.md` — health check configuration in containers
