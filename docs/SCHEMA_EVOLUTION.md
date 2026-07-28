# Schema Evolution Standards

## Philosophy

From Kleppmann: "Data outlives code. Schema evolution is the art of making changes without breaking consumers."

Every schema change must be backward-compatible. Old and new versions must coexist during rolling deployments.

## Serialization Formats

| Format | Use Case | Schema Registry | Language Support |
|--------|----------|-----------------|-----------------|
| Protobuf | Inter-service communication (gRPC) | Required | All three |
| JSON | REST APIs, browser clients | Optional (JSON Schema) | Native |
| Avro | Kafka event payloads | Required | Java, Go |
| Plain JSON (no schema) | Quick prototypes | Not recommended | — |

### Protobuf (Preferred for Inter-service)

```protobuf
syntax = "proto3";

message User {
    string id = 1;
    string email = 2;
    string display_name = 3;
    // NEVER remove or repurpose field numbers
    // reserved 4 for future use
}
```

### Rules

- Field numbers never change (mark removed fields as `reserved`)
- New fields are optional (no `required`)
- Default values must be safe for old consumers
- Never change type of existing field — create new field instead
- Deprecate fields with `[deprecated = true]` before removing

## Schema Registry

### Required Service

Every service ecosystem must have a schema registry:

- **Confluent Schema Registry** for Kafka/Avro
- **buf Schema Registry (BSR)** for Protobuf
- **JSON Schema Store** for REST APIs

### Registry Policies

| Policy | Rule |
|--------|------|
| Backward | New schema can read data written with old schema (default) |
| Forward | Old schema can read data written with new schema |
| Full | Both backward and forward compatible |
| Transitive | Compatibility checked against all previous versions, not just latest |

### Compatibility Rules (Avro)

| Change | Compatible? |
|--------|------------|
| Add optional field with default | ✅ Backward |
| Remove field with default | ✅ Forward |
| Add required field (no default) | ❌ Breaking |
| Remove required field | ❌ Breaking |
| Rename field | ❌ Breaking (use alias) |
| Change field type | ❌ Breaking (create new field) |
| Add enum value | ✅ Backward (with default) |
| Remove enum value | ❌ Breaking |

## REST API Evolution

### Versioning Strategy

URL-based versioning: `/v1/`, `/v2/`

| Change | Version Bump Needed? |
|--------|---------------------|
| Add new endpoint | No |
| Add optional field to response | No |
| Add optional request parameter | No |
| Remove field from response | Yes (v2) |
| Change field type | Yes (v2) |
| Make required field optional | No |
| Make optional field required | Yes (v2) |
| Change endpoint URL | Yes (v2) |

### API Compatibility Check

Automate with:

- OpenAPI diff tools (`openapi-diff`, `swagger-diff`)
- Contract tests (Pact) — consumer-driven compatibility
- CI gate: reject PRs that break existing consumers

```yaml
# CI step example
- name: Check API Compatibility
  run: |
    openapi-diff compare \
      --source main-spec.yaml \
      --target branch-spec.yaml \
      --fail-on-incompatible
```

## Database Migration

### Migration Naming

```
V{version}__{description}.sql
```

Examples:
- `V1__create_users.sql`
- `V2__add_display_name_to_users.sql`
- `V3__deprecate_old_email_format.sql`

### Migration Rules

| Rule | Why |
|------|-----|
| Always add, never remove columns | Rolling deployments need old code to work |
| New columns must be nullable or have default | Old code won't set the column |
| Rename is two-step: add new column, migrate, remove old | Zero-downtime deployments |
| Index additions are safe | Read-only operation |
| Index drops wait until unused | Verify with pg_stat_user_indexes first |

### Zero-Downtime Migration Pattern

```
Phase 1: Add new column (nullable) + new index
Phase 2: Deploy code that writes both old and new
Phase 3: Backfill data for existing rows
Phase 4: Deploy code that reads/writes only new
Phase 5: Remove old column
```

## Kafka / Event Schema Evolution

### Message Structure

```json
{
    "schema_version": 3,
    "event_id": "evt_abc123",
    "event_type": "UserCreated",
    "timestamp": "2024-01-01T12:00:00Z",
    "payload": {
        "id": "user_123",
        "email": "user@example.com"
    }
}
```

### Event Schema Rules

- Event types are immutable — never change the meaning of an existing event type
- Create a new event type for breaking changes (`UserCreated_v2`)
- Consumers subscribe to specific event versions
- Deprecate old events with a TTL (e.g., emit both versions for 30 days)

### Schema Migration for Events

```java
// Publisher emits both versions during migration
@Service
public class UserEventPublisher {
    @Deprecated
    public void publishUserCreated_v1(User user) {
        kafka.send("users", new UserCreated_v1(user.getId(), user.getEmail()));
    }

    public void publishUserCreated_v2(User user) {
        kafka.send("users", new UserCreated_v2(user.getId(), user.getEmail(), user.getDisplayName()));
    }
}
```

## See Also

- `docs/CODING_CONVENTIONS.md` — naming conventions for versioned types
- `docs/TESTING.md` — contract testing for API compatibility
- `docs/ARCHITECTURE.md` — API versioning in microservices
