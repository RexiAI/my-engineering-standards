# Data Storage Decision Standards

## Philosophy

From Kleppmann: "No single storage engine is optimal for all use cases. Choosing the right data model is the most impactful architectural decision."

## Decision Tree

```
What type of data?
├── Structured with complex relationships?
│   ├── ACID required, complex queries, joins?
│   │   └── Relational (PostgreSQL)
│   ├── Flexible schema, rapid iteration?
│   │   └── Document (MongoDB)
│   └── Highly connected data (graphs, networks)?
│       └── Graph (Neo4j)
├── Unstructured or semi-structured?
│   ├── Full-text search?
│   │   └── Search engine (Elasticsearch)
│   ├── Time-series (metrics, logs)?
│   │   └── Time-series DB (VictoriaMetrics)
│   └── Blob storage (files, images)?
│       └── Object store (S3)
├── High-throughput key-value?
│   ├── In-memory cache?
│   │   └── Redis / Memcached
│   └── Durable KV store?
│       └── DynamoDB / FoundationDB
└── Analytics / OLAP?
    └── Columnar (ClickHouse, Redshift)
```

## Storage Engine Comparison

### Relational (PostgreSQL)

| Attribute | Value |
|-----------|-------|
| Consistency | ACID, Serializable |
| Access Pattern | Complex queries, joins, transactions |
| Schema | Strict, migrations required |
| Scaling | Vertical (primary), read replicas |
| Best For | Business transactions, financial data, inventory |

### Document (MongoDB)

| Attribute | Value |
|-----------|-------|
| Consistency | Configurable (strong or eventual) |
| Access Pattern | Primary-key lookup, simple queries |
| Schema | Flexible, embedded documents |
| Scaling | Horizontal (native sharding) |
| Best For | Product catalogs, content management, event sourcing |

### Key-Value (Redis)

| Attribute | Value |
|-----------|-------|
| Consistency | Strong (single-threaded) |
| Access Pattern | O(1) get/set |
| Persistence | Optional (RDB/AOF) |
| Scaling | Cluster mode |
| Best For | Cache, session, rate limiting, real-time leaderboards |

### In-Memory vs Durable

| Criteria | In-Memory (Redis) | Durable (PostgreSQL) |
|----------|-------------------|---------------------|
| Data loss tolerance | Acceptable | Not acceptable |
| Access pattern | Simple KV | Complex queries |
| Durability | Optional persistence | Transaction log |
| Cost per GB | $15-30/mo | $0.10-1/mo |

## Cache Strategy

### Cache-Aside (Lazy Loading)

```
1. Read → check cache → miss → load from DB → populate cache → return
2. Write → write to DB → invalidate cache
```

### Write-Through

```
1. Write → write to cache → write to DB → return
2. Best for: Read-heavy, write-friendly data
```

### Write-Behind

```
1. Write → write to cache → return immediately → async write to DB
2. Best for: High-throughput writes (with data loss risk)
```

### Cache Invalidation

| Pattern | When to Use |
|---------|-------------|
| TTL-based | Data becomes stale naturally |
| Direct invalidation (delete key) | Know exactly when data changes |
| Event-driven invalidation | Cross-service cache consistency |

## Search Strategy

### When to use full-text search vs DB query

| Use Full-Text Search | Stick with DB Query |
|---------------------|-------------------|
| Fuzzy matching, typos | Exact match lookups |
| Relevance scoring | Simple WHERE clauses |
| Faceted navigation | Basic filtering |
| Multi-field full-text | Single-field search |
| > 1M documents | < 100K documents |

## See Also

- `docs/ARCHITECTURE.md` — data access patterns in layers
- `docs/SCHEMA_EVOLUTION.md` — migration strategy for schema changes
- `docs/SCALABILITY.md` — scaling storage as traffic grows
