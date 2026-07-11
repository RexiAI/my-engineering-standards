# Eventual Consistency Standards

## Philosophy

From Kleppmann: "Strong consistency is expensive. Eventual consistency is the default in distributed systems. The key is understanding what your application tolerates."

## Decision Framework

When deciding between consistency models:

```
Is this read after a user action in the same request?
├── Yes → Is it the same user's own data?
│   ├── Yes → Read-your-writes consistency
│   └── No  → Is the data critical for business decisions?
│       ├── Yes → Strong consistency (linearizable)
│       └── No  → Eventual consistency
└── No  → Is this a background/reporting read?
    ├── Yes → Eventual consistency is fine
    └── No  → See latency requirements below
```

## Consistency Models

| Model | Guarantee | Example | Cost |
|-------|-----------|---------|------|
| Linearizability | Every read sees latest write | Payment authorization | High (sync replication) |
| Read-your-writes | User sees own writes immediately | Profile update | Medium (session stickiness) |
| Monotonic reads | Never go back in time | Timeline scrolling | Medium |
| Eventual | All replicas converge eventually | Analytics, search index | Low |

## Read-Your-Writes Implementation

### Session Stickiness

Route user to the same replica after write:

```java
// Write operation → replicate with read-your-writes consistency
public User updateProfile(String userId, ProfileUpdate update) {
    User updated = repository.save(userId, update);
    cache.set("user:" + userId, updated, Duration.ofMinutes(5));
    return updated;
}

// Read operation → prefer cache if available
public Optional<User> getProfile(String userId) {
    User cached = cache.get("user:" + userId);
    if (cached != null) return Optional.of(cached);
    return repository.findById(userId);
}
```

### Quorum-Based Approaches

| Operation | Read Quorum | Write Quorum | Guarantee |
|-----------|------------|-------------|-----------|
| Strong | N (all) | N (all) | Linearizable but unavailable on failure |
| Quorum | R > N/2 | W > N/2 | Strong if R + W > N |
| Eventual | 1 | 1 | Fast, stale reads possible |

Default: R=1, W=N (read from any, write to all) for eventual consistency with durable writes.

## Conflict Resolution

### Last-Writer-Wins (LWW)

Simplest approach. Acceptable when data loss is tolerable and concurrent writes are rare.

```java
record UserProfile(String id, String email, String displayName, long version, Instant updatedAt) {
    public UserProfile mergeWith(UserProfile other) {
        // LWW: the one with the newer timestamp wins
        return this.updatedAt.isAfter(other.updatedAt) ? this : other;
    }
}
```

### Merge Semantics (CRDTs)

For collaborative data (counters, sets, maps) use CRDTs to guarantee convergence without conflicts:

| Data Type | CRDT | Merge Rule |
|-----------|------|------------|
| Counter | G-Counter (grow-only) | Max of each replica's value |
| Counter (decrementable) | PN-Counter | Sum of increments and decrements |
| Set (add-only) | G-Set | Union |
| Set (add+remove) | OR-Set | Per-element add/remove vectors |
| Map | LWW-Register per field | Per-field LWW |

## When to Accept Eventual Consistency

### Safe

- Content delivery (CDN, search index, caching layer)
- Analytics dashboards, reporting
- User preferences, profile data (non-critical)
- Aggregations, leaderboards
- Read replicas for reporting

### Needs Strong Consistency

- Payment processing, balance updates
- Inventory reservation
- User authentication state
- Any operation where stale data causes data loss or incorrect behavior

## Monitoring Staleness

Track replication lag and alert when it exceeds SLO:

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `replication_lag_ms` | Time since last replication | > 1000ms |
| `stale_read_ratio` | Reads served from stale replica | > 1% of reads |
| `conflict_rate` | Concurrent writes to same key | > 0.1% of writes |

## See Also

- `docs/SAGA_PATTERN.md` — consistency across services in long-running workflows
- `docs/IDEMPOTENCY.md` — avoiding duplicate writes under eventual consistency
