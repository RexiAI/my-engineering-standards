# Observability Standards

## Philosophy

From Kleppmann: "Observability means you can understand what the system is doing without deploying new code."

Three pillars: logging, metrics, tracing. All three are mandatory.

## Distributed Tracing

### OpenTelemetry

All services must use OpenTelemetry SDK for tracing. Do not use vendor-specific tracers (Datadog, New Relic, X-Ray).

### Trace Context Propagation

Use W3C Trace Context standard (`traceparent` header):

```
traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
```

- `trace-id` (32 hex chars) — shared across all spans in trace
- `span-id` (16 hex chars) — current span
- `trace-flags` — sampling decision

### Span Attributes

Every span must include:

| Attribute | Source | Example |
|-----------|--------|---------|
| `service.name` | Config | `user-service` |
| `service.version` | Build | `1.2.3` |
| `http.method` | Request | `POST` |
| `http.url` | Request | `/v1/users` |
| `http.status_code` | Response | `200` |
| `user.id` | Auth context | `user_123` (omit for anonymous) |
| `error` | Span status | `true` |

### Sampling

| Traffic Level | Sampling Rate |
|--------------|---------------|
| < 100 req/s | 100% |
| 100-1000 req/s | 10% |
| > 1000 req/s | 1% + always sample on error |

Always sample traces containing errors regardless of rate.

## Structured Logging

### Format

All logs must be structured JSON with consistent fields:

```json
{
    "timestamp": "2024-01-01T12:00:00.000Z",
    "level": "INFO",
    "message": "User authenticated successfully",
    "trace_id": "0af7651916cd43dd8448eb211c80319c",
    "span_id": "b7ad6b7169203331",
    "service": "auth-service",
    "environment": "production",
    "user_id": "user_123",
    "duration_ms": 42
}
```

### Log Levels

| Level | Usage |
|-------|-------|
| ERROR | Operation failed, human intervention likely needed |
| WARN | Degraded behavior, non-critical failure |
| INFO | State changes, successful operations |
| DEBUG | Diagnostic details (disabled in production by default) |
| TRACE | High-frequency internal details (never in production) |

### What to Log

- **Service method boundaries**: input params, result/error, duration
- **State transitions**: created, updated, deleted, archived
- **External calls**: URL, method, status, duration
- **Auth decisions**: user, action, resource, allowed/denied
- **Errors**: full stack trace (but never nested causes beyond depth 10)

### What NOT to Log

- Passwords, tokens, API keys (mask to `***`)
- PII (names, emails, phone numbers — use `user_id` instead)
- Request bodies larger than 1KB (log trimmed version)
- Binary data, file contents

## Metrics

### Required Metrics

Every service must expose:

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `http_requests_total` | Counter | `method`, `path`, `status` | Total HTTP requests |
| `http_request_duration_ms` | Histogram | `method`, `path` | Request latency (p50, p95, p99) |
| `service_errors_total` | Counter | `type` | Error count by category |
| `db_query_duration_ms` | Histogram | `operation`, `table` | Database query latency |
| `circuit_breaker_state` | Gauge | `name` | Circuit breaker state (0=closed, 1=open, 2=half-open) |
| `message_processed_total` | Counter | `queue`, `status` | Message processing count |
| `message_processing_duration_ms` | Histogram | `queue` | Message processing latency |
| `requests_in_flight` | Gauge | `service` | Current concurrent requests |
| `cache_hit_ratio` | Gauge | `cache` | Cache hit rate (0-1) |

### Metric Naming

- Use `_total` suffix for counters
- Use `_duration_ms` suffix for latency histograms
- Use lowercase with underscores
- Prefix with domain: `http_`, `db_`, `cache_`, `queue_`

### Prometheus Endpoint

All services expose `/metrics` in Prometheus format (OpenMetrics):

```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/v1/users",status="200"} 1234
```

## Alerting Rules

### Threshold Alerts

| Alert | Condition | Severity | Response |
|-------|-----------|----------|----------|
| High Error Rate | `http_requests_total{status=~"5.."} > 1% of total` over 5m | Critical | On-call paged |
| High Latency | `p99 http_request_duration_ms > 2000` over 5m | Critical | On-call paged |
| Circuit Breaker Open | `circuit_breaker_state > 0` | Warning | Slack notification |
| Cache Hit Ratio Low | `cache_hit_ratio < 0.3` over 10m | Warning | Review query patterns |
| Message Backlog | `queue_depth > 1000` | Critical | Auto-scale consumer |
| Health Check Failing | `up{job="<service>"} == 0` over 1m | Critical | Auto-remediation + page |

### Rate of Change Alerts

- Error rate increasing 50% week-over-week → review
- P50 latency increasing 20% over 24h → investigate
- Traffic spike > 3x normal → auto-scale + review

## SLI / SLO

### Standard SLIs

| SLI | Measurement | Target |
|-----|------------|--------|
| Availability | `(1 - 5xx / total) * 100` over 30d | >= 99.9% |
| Latency | p99 HTTP response time | <= 500ms |
| Throughput | Requests per second | >= capacity plan |
| Freshness | Time from event to visibility | <= 30s (async) |

### Error Budget

Error budget = 100% - SLO target. Spend on:
- Feature development when budget > 50% remaining
- Reliability work when budget < 30% remaining
- Stop all non-critical releases when budget exhausted

## Dashboard Requirements

Every service must have at least one Grafana dashboard covering:

1. **Red metrics**: Request rate, Error rate, Duration (4 golden signals)
2. **Dependencies**: Downstream service health, DB latency, cache hit ratio
3. **Resources**: CPU, memory, GC, connection pools
4. **Business**: Domain-specific KPIs (accounts created, orders placed)

## See Also

- `docs/RESILIENCE.md` — circuit breaker, retry patterns
- `docs/DEPLOYMENT.md` — health check, readiness, liveness probes
- `docs/SECURITY.md` — audit logging requirements
