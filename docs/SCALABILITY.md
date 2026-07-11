# Scalability Standards

## Philosophy

From Kleppmann: "Scalability is not a property of the system; it's a relationship between load and performance. Define the load parameters first, then design for them."

## Stateless Services

Every service must be stateless. All state must be externalized:

| State Type | External Store |
|------------|---------------|
| Session | Redis (distributed session) |
| Cache | Redis / Memcached |
| Configuration | Environment variables / Config service |
| Authentication tokens | Token store (Redis) |
| Uploaded files | Object store (S3) |

## Load Parameters

Every service must document its expected load:

```
Typical throughput:    500 req/s
Peak throughput:       2000 req/s (4x typical)
Data volume:           ~10GB
User base:             100K DAU
Concurrent connections: 1000
Max response time:     500ms (p99)
```

## Connection Pooling

### Database Connection Pool

| Service Tier | Min Pool | Max Pool | Idle Timeout |
|-------------|----------|----------|-------------|
| Small | 5 | 10 | 30 min |
| Medium | 10 | 30 | 30 min |
| Large | 20 | 50 | 30 min |

Formula: `maxPool = (maxConcurrentRequests * avgQueryTime) / 1000 * 1.5`

### HTTP Connection Pool

| Destination | Max Connections | Keep-alive | Idle Timeout |
|------------|----------------|------------|-------------|
| Internal service | 50 | 30s | 5s |
| External API | 10 | 10s | 1s |

## Thread Pool Sizing

### CPU-Bound Work

```
pool size = number of CPU cores + 1
```

### I/O-Bound Work

```
pool size = number of CPU cores * (1 + wait time / service time)
```

### Default Sizing

| Workload Type | Thread Pool | Queue |
|--------------|-------------|-------|
| HTTP requests | 200 | 100 |
| Database queries | 50 | 50 |
| External API calls | 20 | 20 |
| Background jobs | 10 | 50 |

## Horizontal Scaling Triggers

| Metric | Auto-Scale Trigger | Scale Cooldown |
|--------|-------------------|----------------|
| CPU > 70% | Add 1 instance | 5 min |
| Memory > 80% | Add 1 instance | 5 min |
| Request queue depth > 100 | Add 2 instances | 3 min |
| P99 latency > 500ms | Add 1 instance | 5 min |
| All metrics normal for 15 min | Remove 1 instance | 15 min |

## Caching

### Multi-Level Cache

```
Level 1: In-memory (local to service instance)
  → TTL: 60s, Size: 100MB max
  → Use: Frequently accessed, rarely changed data
Level 2: Distributed (Redis)
  → TTL: 5 min, Size: 1GB max
  → Use: Shared across instances, moderate churn
Level 3: Database
  → Indexed, query-optimized
  → Use: Everything else
```

### Cache-Aside Pattern

```java
public User getUser(String id) {
    // Level 1: local cache
    User user = localCache.get(id);
    if (user != null) return user;

    // Level 2: distributed cache
    user = redis.get("user:" + id);
    if (user != null) {
        localCache.put(id, user);
        return user;
    }

    // Level 3: database
    user = repository.findById(id);
    redis.set("user:" + id, user, Duration.ofMinutes(5));
    localCache.put(id, user);
    return user;
}
```

## Performance Budgets

| Metric | Budget | Critical |
|--------|--------|----------|
| P50 response time | < 100ms | < 500ms |
| P95 response time | < 300ms | < 1s |
| P99 response time | < 500ms | < 2s |
| Error rate | < 0.1% | < 1% |
| Cache hit ratio | > 80% | > 60% |
| DB query time | < 10ms (indexed) | < 100ms |
| Startup time | < 30s | < 60s |

## Load Testing

### Requirements

Every service must have a load test suite:

| Test Type | Target | Frequency |
|-----------|--------|-----------|
| Baseline | Expected typical throughput | Pre-release |
| Stress | 2x expected peak | Pre-release |
| Soak | Typical throughput for 1hr | Pre-release |
| Spike | Sudden 10x traffic burst | Pre-release |

### Tools

- Java: Gatling
- Go: `vegeta` or custom benchmark
- Node: `k6` or `artillery`

## See Also

- `docs/DATA_STORAGE_DECISIONS.md` — choosing the right storage engine
- `docs/DEPLOYMENT.md` — container resource limits
- `docs/OBSERVABILITY.md` — monitoring auto-scale triggers
