# Message Delivery Standards

## Philosophy

From Kleppmann: "The network is unreliable. Message delivery guarantees define what happens when things fail."

## Delivery Guarantees

| Guarantee | Meaning | Mechanism | Cost |
|-----------|---------|-----------|------|
| At-most-once | Message may be lost, never duplicated | Fire-and-forget | Lowest |
| At-least-once | Message may be duplicated, never lost | Retry + ack after processing | Default |
| Exactly-once | Message delivered exactly once | Idempotent consumer + dedup | Highest |

**Default: at-least-once.** Accept exactly-once semantics only when duplicates cause data integrity issues (payments, inventory).

## Message Queue Patterns

### Standard Consumer

```java
@Component
public class OrderEventConsumer {
    private final OrderService orderService;
    private final DeduplicationStore dedupStore;

    @KafkaListener(topics = "orders", groupId = "order-service")
    public void onMessage(ConsumerRecord<String, OrderEvent> record) {
        String messageId = record.key();

        // Deduplicate
        if (!dedupStore.tryAcquire("orders:" + messageId, Duration.ofHours(24))) {
            log.debug("Duplicate message ignored: {}", messageId);
            return;
        }

        // Process (with retry)
        try {
            orderService.process(record.value());
            log.info("Processed order event: {}", messageId);
        } catch (Exception e) {
            log.error("Failed to process order event: {}", messageId, e);
            throw e; // Causes retry per consumer config
        }
    }
}
```

### Retry and Dead Letter Queue

```yaml
# Kafka consumer config
spring:
  kafka:
    consumer:
      max-retries: 3
      retry-backoff-ms: 1000
    listener:
      dead-letter-topic: orders-dlt
      concurrency: 3
```

### Dead Letter Queue Handling

Messages that fail after all retries go to a DLQ. DLQ monitoring must:

1. Alert on any message in DLQ (Slack, PagerDuty)
2. Provide a replay mechanism (via admin endpoint or tool)
3. Log the full message and failure reason for debugging

```java
// DLQ replay endpoint
@PostMapping("/admin/dlq/replay")
public void replayDlq(@RequestParam String topic) {
    deadLetterService.replay(topic, (message) -> {
        return kafkaTemplate.send(topic, message.key(), message.value());
    });
}
```

## Consumer Configuration

### Concurrency

| Queue Type | Default Partitions | Consumers |
|-----------|-------------------|-----------|
| Event (async) | 3 | 3 |
| Command (sync) | 1-2 | 1-2 |
| Dead Letter | 1 | 1 |

### Retry Configuration

```
maxRetries: 5
initialBackoff: 500ms
backoffMultiplier: 2
maxBackoff: 30s
```

## Message Schema

Every message must include:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `event_id` | UUID | Yes | Unique identifier for deduplication |
| `event_type` | String | Yes | e.g., "OrderCreated" |
| `event_version` | Integer | Yes | Schema version for evolution |
| `timestamp` | ISO 8601 | Yes | When the event occurred |
| `payload` | Object | Yes | Business data |
| `trace_id` | String | Yes | For distributed tracing |

## Topics and Queues

### Naming Convention

```
{direction}-{domain}-{event-type}

Direction: event | command | reply
Example: event-order-created
```

| Topic Type | Pattern | Example |
|------------|---------|---------|
| Event | `event-{domain}-{action}` | `event-order-created` |
| Command | `cmd-{domain}-{action}` | `cmd-payment-charge` |
| Dead Letter | `dlq-{source-topic}` | `dlq-event-order-created` |
| Retry | `retry-{source-topic}` | `retry-event-order-created` |

## See Also

- `docs/IDEMPOTENCY.md` — consumer-side deduplication
- `docs/OUTBOX_PATTERN.md` — reliable event publishing
- `docs/SAGA_PATTERN.md` — multi-step event-driven workflows
- `docs/RESILIENCE.md` — retry and circuit breaker for consumers
