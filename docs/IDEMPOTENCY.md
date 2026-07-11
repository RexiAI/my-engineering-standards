# Idempotency Standards

## Philosophy

From Kleppmann: "Idempotency is the foundation of reliable message processing and safe retries."

Every mutating endpoint must be safe to retry without side effects.

## Idempotency Key Pattern

### How It Works

1. Client generates a unique key (`Idempotency-Key` header)
2. Server checks key in idempotency store (Redis, key-value DB)
3. If key exists → return cached response
4. If key not found → process request, store result, return

### Key Generation

| Source | Format | Example |
|--------|--------|---------|
| Client | UUID v4 | `550e8400-e29b-41d4-a716-446655440000` |
| Message consumer | Message ID | `msg_abc123` |
| Scheduled job | Job ID + timestamp | `job-456-2024-01-01T00:00:00Z` |

### Key Scope

```
idempotency:{service}:{operation}:{key}
```

TTL: 24 hours (configurable per operation).

### Response Cache

```json
{
    "statusCode": 201,
    "headers": { "Idempotency-Replayed": "true" },
    "body": { "id": "user_789", "created": true }
}
```

## Implementation

### Server (Idempotency Store)

```java
public class IdempotencyService {
    private final RedisTemplate<String, IdempotencyRecord> redis;

    public <T> Optional<T> getCachedResult(String key, Class<T> type) {
        return Optional.ofNullable(redis.opsForValue().get(key))
            .map(r -> deserialize(r.getResponse(), type));
    }

    public void cacheResult(String key, Object result, Duration ttl) {
        redis.opsForValue().set(key,
            new IdempotencyRecord(serialize(result), Instant.now()),
            ttl);
    }
}
```

### Server (Middleware)

```java
@Component
public class IdempotencyFilter implements Filter {
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain) {
        HttpServletRequest req = (HttpServletRequest) request;
        String key = req.getHeader("Idempotency-Key");

        if (isReadMethod(req.getMethod()) || key == null) {
            chain.doFilter(request, response);
            return;
        }

        // Check for cached response
        var cached = idempotencyService.getCachedResult(key);
        if (cached.isPresent()) {
            httpResponse.setHeader("Idempotency-Replayed", "true");
            httpResponse.setStatus(200);
            httpResponse.getWriter().write(cached.get());
            return;
        }

        // Process and cache
        CachedBodyHttpServletResponse wrapper = new CachedBodyHttpServletResponse(httpResponse);
        chain.doFilter(request, wrapper);
        idempotencyService.cacheResult(key, wrapper.getBody());
    }
}
```

### Client (Request Header)

```java
// Feign interceptor
@Bean
public RequestInterceptor idempotencyInterceptor() {
    return template -> {
        if (isMutating(template.method())) {
            template.header("Idempotency-Key", UUID.randomUUID().toString());
        }
    };
}
```

## Deduplication in Message Consumers

### At-Least-Once Delivery

Message queues deliver at-least-once. Consumers must deduplicate.

```java
@Component
public class OrderEventConsumer {
    private final DeduplicationStore dedupStore;

    @KafkaListener(topics = "orders")
    public void onMessage(OrderEvent event) {
        if (!dedupStore.tryAcquire(event.messageId(), Duration.ofHours(24))) {
            log.debug("Skipping duplicate message {}", event.messageId());
            return;
        }
        processOrder(event);
    }
}
```

### Deduplication Store

Prefer Redis with `SETNX` + TTL for distributed deduplication:

```bash
SETNX dedup:orders:msg_abc123 "processed" EX 86400
```

- `SETNX` returns 1 → first time, proceed
- `SETNX` returns 0 → duplicate, skip

## Safe Retries for Idempotent Endpoints

| Guarantee Level | Mechanism | Idempotent? |
|----------------|-----------|-------------|
| At-most-once | No retry | Yes (trivially) |
| At-least-once | Retry with idempotency key | Yes |
| Exactly-once | Idempotent operations + dedup | Yes (practically) |

## Non-Idempotent Operations

Some operations cannot be made idempotent naturally:

| Operation | Mitigation |
|-----------|------------|
| Send email | Check `already_sent` flag in DB before sending |
| External payment | Use payment provider idempotency key |
| Decrement inventory | Check `decrement_id` before applying |

## See Also

- `docs/RESILIENCE.md` — retry, circuit breaker patterns
- `docs/OBSERVABILITY.md` — tracking replayed requests in metrics
