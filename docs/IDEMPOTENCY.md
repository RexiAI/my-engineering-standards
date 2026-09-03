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

## Serverless Idempotency: Module State Is Not Durable

In a serverless/FaaS runtime (Vercel, AWS Lambda, Cloud Run scaled to zero), module-level
state — `const seen = new Set()`, a module-scope `Map`, an in-process LRU — is scoped to a
single instance and lost on cold start. Providers retry webhooks aggressively, and concurrent
invocations each get their own memory, so module state produces duplicate side effects:
duplicate emails, duplicate charges, duplicate downstream events.

Module state is a **warm-instance fast path**, never the authoritative deduplication record.

| Layer | Role | Survives cold start / concurrency? |
|---|---|---|
| Module-scope set/map | Cheap short-circuit for repeats on the same warm instance | No |
| Durable marker (Redis `SETNX`, DB unique key) | Authoritative dedup record | Yes |

The correct shape: key the durable marker on the provider's event id, and write it **after**
the handler completes successfully — a marker written before the work turns a crash into a
silently dropped event. The in-memory set may remain in front of it as an optimization.

```ts
if (seen.has(event.id)) return ok();            // warm-instance fast path only
if (await markerExists(event.id)) return ok();  // authoritative
await handle(event);
await writeMarker(event.id);                    // after success
seen.add(event.id);
```

When no KV store or database exists, an external system already in the request path (for
example the payment provider's customer or metadata store) can hold the marker. Any such
store with a key-count or size limit **requires an explicit pruning strategy**, and the bound
must be documented next to the code that writes markers.

Stated honestly: check-then-act deduplication is still racy under truly simultaneous delivery
— two invocations can both read "absent" before either writes. This narrows the duplicate
window, it does not deliver exactly-once. Where the store offers a compare-and-set primitive
(`SETNX`, unique constraint), use it; where it does not, say so in the design.

See the "Send email" row of §Non-Idempotent Operations — the `already_sent` flag is exactly
this durable marker, and a module-scope set is not a substitute for it.

## One Charge Path Per Transaction

A money flow must have exactly one code path that captures funds. If both an upfront charge
and a post-hoc/reconciliation charge exist for the same transaction, the customer is billed
twice. This is a design defect, not a bug to patch downstream with refunds or filters.

- When a reservation precedes a final variable charge, the reservation is a **zero-amount
  authorization/hold** and the final charge is the sole capture.
- The design must state explicitly which single path captures.
- A test must assert that the other path captures zero.

| Path | Captures | Test assertion |
|---|---|---|
| Reservation / hold | 0 | Amount captured == 0 |
| Final / reconciliation | Full variable amount | Amount captured == computed total |

### One-time entitlements

Free trial, first-session-free, one-per-customer discount: reading the entitlement at one
point and burning it at another is a TOCTOU window — two concurrent transactions can both
read "unused". Read-and-burn must be as close to atomic as the backing store allows
(compare-and-set, conditional update, unique constraint).

Where the store has no compare-and-set, document that the window is **narrowed, not
eliminated**, and make the burn idempotent so a repeat burn is detectable rather than silently
granting the entitlement twice.

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
