# Outbox Pattern Standards

## Philosophy

From Kleppmann: "Atomic writes to both the database and the message queue require distributed transactions — unless you use the outbox pattern."

The outbox pattern guarantees at-least-once message delivery without distributed transactions. Write the event to a database table in the same transaction as the business operation. A separate relay process publishes events to the message broker.

## Problem

```
1. INSERT INTO orders (...) VALUES (...)   ← succeeds
2. Send message to queue                   ← fails

Result: Order saved but no event published.
Downstream services don't know about the order.
```

## Solution

```
1. BEGIN TRANSACTION
2. INSERT INTO orders (...) VALUES (...)
3. INSERT INTO outbox (event_id, event_type, payload, created_at) VALUES (...)
4. COMMIT                              ← Atomic: both or neither
5. Outbox relay reads, publishes, deletes
```

## Database Schema

```sql
CREATE TABLE outbox (
    event_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type      VARCHAR(100) NOT NULL,     -- e.g., "OrderCreated"
    payload         JSONB NOT NULL,            -- Full event payload
    aggregate_type  VARCHAR(50) NOT NULL,       -- e.g., "order"
    aggregate_id    VARCHAR(50) NOT NULL,       -- e.g., "order_123"
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    published_at    TIMESTAMP                   -- NULL until published
);

CREATE INDEX idx_outbox_unpublished ON outbox (created_at)
    WHERE published_at IS NULL;
```

## Outbox Relay

### Polling Relay (Simple)

```java
@Component
public class OutboxRelay {
    private final JdbcTemplate jdbc;
    private final EventPublisher publisher;

    @Scheduled(fixedDelay = 1000) // Every second
    @Transactional
    public void publishPending() {
        List<OutboxEvent> events = jdbc.query(
            "SELECT * FROM outbox WHERE published_at IS NULL ORDER BY created_at LIMIT 50",
            outboxRowMapper);

        for (OutboxEvent event : events) {
            try {
                publisher.publish(event.eventType(), event.payload());
                jdbc.update("UPDATE outbox SET published_at = NOW() WHERE event_id = ?",
                    event.eventId());
            } catch (Exception e) {
                log.error("Failed to publish event {}: {}", event.eventId(), e.getMessage());
                // Will retry next iteration
            }
        }
    }
}
```

### Transaction Log Tailing (High Throughput)

For high-volume services, use CDC (Change Data Capture) with Debezium or similar to stream outbox rows from the database transaction log. This avoids polling overhead.

## Idempotent Event Processing

Consumers must handle duplicate events (relay may publish after crash but before marking as published):

```java
// Consumer deduplication
if (dedupStore.alreadyProcessed(event.eventId())) {
    log.debug("Skipping duplicate event {}", event.eventId());
    return;
}
processEvent(event);
dedupStore.markProcessed(event.eventId(), Duration.ofDays(7));
```

## Ordering Guarantees

| Approach | Ordering | Throughput | Complexity |
|----------|----------|------------|------------|
| Polling relay (single partition) | Strict order per aggregate | ~1000/s | Low |
| Partition per aggregate | Strict order per aggregate | ~10000/s | Medium |
| Debezium CDC | Per-table commit order | ~100000/s | High |

## Cleanup

Delete published outbox rows after TTL:

```sql
DELETE FROM outbox WHERE published_at < NOW() - INTERVAL '7 days';
```

## Comparison

| Pattern | Guarantee | Complexity | When to Use |
|---------|-----------|------------|-------------|
| Outbox | At-least-once, ordered | Medium | Default — most reliable |
| Kafka Transactions | Exactly-once | High | Kafka-only ecosystem |
| 2PC (XA) | Atomic | High | Legacy systems, short duration |

## Required Tests

All five scenarios below are **required** for any service implementing this pattern.
Copy the matching template from `ci/templates/tests/` and fill in the TODOs.

| # | Scenario | Template |
|---|----------|----------|
| 1 | Business write + outbox insert are atomic (rollback both on failure) | `OutboxIntegrationTestTemplate.java` / `outbox_integration_test.go` / `outbox.integration.test.ts` |
| 2 | Relay publishes unpublished outbox events | same |
| 3 | Relay marks events as published — no re-publish on next run | same |
| 4 | Consumer deduplicates duplicate event delivery | same |
| 5 | Cleanup deletes published rows older than TTL | same |

Test files must match naming patterns: `*OutboxTest*`, `*outbox*_test.go`, or `*outbox*.integration.test.ts`.
The `check-saga-tests.sh` CI gate blocks PRs that introduce outbox code without these files.

## CI Quality Gates

Automated gates run on every PR when outbox code is detected (via `detect-saga-outbox.sh`).
Zero overhead for services that do not use this pattern.

| Gate | Script | Blocks PR |
|------|--------|-----------|
| Outbox schema has all required columns | `lint-outbox-schema.sh` | Yes |
| Partial index on `published_at IS NULL` exists | `lint-outbox-schema.sh` | Yes |
| Cleanup mechanism defined | `lint-outbox-schema.sh` | Yes |
| Relay component exists | `check-outbox-relay.sh` | Yes |
| Consumer deduplication logic exists | `check-outbox-relay.sh` | Yes |
| Integration tests present | `check-saga-tests.sh` | Yes |
| Services must not call broker directly — must use outbox | ArchUnit `OutboxArchRules.servicesMustPublishViaOutbox()` | Yes |
| Relay component must not live in controller layer | ArchUnit `OutboxArchRules.outboxRelayMustNotBeInControllerLayer()` | Yes |

**Setup** (child repos): run `init-ci.sh --with-saga` to copy templates and enable the `saga-gates` stage.

## See Also

- `docs/SAGA_PATTERN.md` — event-driven coordination between services
- `docs/IDEMPOTENCY.md` — consumer-side deduplication
- `docs/RESILIENCE.md` — retry, circuit breaker for the relay
