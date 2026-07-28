# Stream Processing Standards

## Philosophy

From Kleppmann: "Stream processing blurs the line between batch and real-time. Databases are state, streams are events. Changes from the database flow through streams to consumers."

## When to Use Stream Processing

| Use Case | Example | Approach |
|----------|---------|----------|
| Event-driven microservices | Order → Payment → Shipping | Kafka + consumer groups |
| Real-time analytics | User click tracking | Kafka Streams / Flink |
| CDC (Change Data Capture) | Sync DB changes to search index | Debezium + Kafka |
| Materialized views | Aggregate counts with low latency | Kafka Streams KTable |
| ETL / Data pipeline | Transform logs to analytics format | Flink batch or streaming |

## Kafka Configuration

### Topic Design

| Property | Default | Notes |
|----------|---------|-------|
| Partitions | 3 | Increase for higher throughput |
| Replication factor | 3 | At least 2 in production |
| Retention | 7 days | Extend for reprocessing scenarios |
| Cleanup policy | `delete` | `compact` for log-compacted topics (keyed data) |
| Max message size | 1MB | Increase only after testing |

### Producer Configuration

```properties
acks=all                    # Wait for all replicas
enable.idempotence=true     # Prevent duplicates
max.in.flight.requests.per.connection=5
batch.size=16384            # 16KB batches
linger.ms=5                 # Wait up to 5ms for batching
compression.type=snappy     # Reduce network usage
```

### Consumer Configuration

```properties
enable.auto.commit=false    # Manual commit after processing
auto.offset.reset=earliest  # Start from beginning on new group
max.poll.records=500        # Batch size per poll
session.timeout.ms=30000    # Consumer health check interval
heartbeat.interval.ms=10000 # Heartbeat frequency
```

## Windowing Strategies

| Window Type | Description | Use Case |
|-------------|-------------|----------|
| Tumbling | Fixed-size, non-overlapping | Aggregations for fixed intervals (hourly counts) |
| Hopping | Fixed-size, overlapping | Smooth rolling metrics (moving average) |
| Sliding | Continuous window around event time | Real-time anomaly detection |
| Session | Window defined by activity gap | User session analysis |

### Example: Tumbling Window (1 min)

```java
KStream<String, ClickEvent> clicks = builder.stream("clicks");

KGroupedStream<String, ClickEvent> grouped = clicks
    .groupByKey();

KTable<Windowed<String>, Long> counts = grouped
    .windowedBy(TimeWindows.of(Duration.ofMinutes(1)))
    .count();
```

## Exactly-Once Semantics

### Idempotent Producer + Transactional Reads

```properties
# Producer: enables exactly-once per partition
enable.idempotence=true
transactional.id=order-service-${INSTANCE_ID}

# Consumer: read committed
isolation.level=read_committed
```

### Kafka Streams Exactly-Once

```properties
processing.guarantee=exactly_once_v2
```

This ensures:
- Each input record is processed exactly once
- Internal state stores and output topics are consistent
- Failures don't produce duplicates or data loss

## Reprocessing

### When to Reprocess

- Fixing a processing bug that consumed incorrect data
- Backfilling a new analytics pipeline with historical data
- Rebuilding a corrupted materialized view

### Strategy

1. Create new consumer group with different `group.id`
2. Reset offset to desired timestamp: `kafka-consumer-groups --reset-offsets --to-datetime 2024-01-01T00:00:00.000Z`
3. Verify output in a shadow topic before switching production
4. Switch production consumer to new offset

```bash
# Reset consumer group to specific timestamp
kafka-consumer-groups --bootstrap-server kafka:9092 \
  --group order-service-v2 \
  --topic orders \
  --reset-offsets \
  --to-datetime 2024-01-01T00:00:00.000Z \
  --execute
```

## State Stores

### When to Use

| Type | Duration | Size Limit | Backup |
|------|----------|------------|--------|
| In-memory | Session only | < 1GB | None (ephemeral) |
| RocksDB (persistent) | Long-lived | < 100GB | Change log topic |
| External (Redis/DB) | Permanent | Unlimited | Replicated |

### RocksDB Configuration

```properties
state.store.rocksdb.block.cache.size=50MB
state.store.rocksdb.write.buffer.size=64MB
state.store.rocksdb.max.write.buffer.number=3
```

## See Also

- `docs/SAGA_PATTERN.md` — event-driven workflows across services
- `docs/OUTBOX_PATTERN.md` — reliable event publishing
- `docs/SCHEMA_EVOLUTION.md` — message schema compatibility
- `docs/OBSERVABILITY.md` — monitoring stream processing lag
