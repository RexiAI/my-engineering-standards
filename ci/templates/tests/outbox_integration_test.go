// outbox_integration_test.go — Outbox integration test template.
//
// Standards reference: docs/OUTBOX_PATTERN.md §Required Tests
//
// HOW TO USE:
//  1. Copy to your service: cp .standards/ci/templates/tests/outbox_integration_test.go \
//                              internal/outbox/{your_service}_outbox_integration_test.go
//  2. Replace all TODO markers with service-specific implementations.
//  3. Add required deps: go get github.com/testcontainers/testcontainers-go
//  4. Run: make test-integration  (or go test -tags integration ./internal/outbox/...)
//
// Build tag "integration" prevents this from running during unit test pass.
// All 5 scenarios required by docs/OUTBOX_PATTERN.md §Required Tests are covered.

//go:build integration

package outbox_test

import (
	"context"
	"database/sql"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// testOutboxSetup holds all test dependencies.
type outboxTestSetup struct {
	db *sql.DB
	// TODO: relay      *OutboxRelay
	// TODO: brokerSpy  *MessageBrokerSpy
	// TODO: dedupStore DedupStore
	// TODO: service    *OrderService
}

func setupOutboxTest(t *testing.T) *outboxTestSetup {
	t.Helper()
	// TODO: start Testcontainers Postgres
	// ctx := context.Background()
	// pgContainer, err := postgres.RunContainer(ctx, ...)
	// require.NoError(t, err)
	// t.Cleanup(func() { pgContainer.Terminate(ctx) })

	// TODO: run migrations, init service, relay, broker spy, dedup store
	// db, _ := sql.Open("pgx", pgContainer.ConnectionString(ctx))
	// return &outboxTestSetup{db: db, relay: NewOutboxRelay(db, brokerSpy), ...}
	return &outboxTestSetup{}
}

func (s *outboxTestSetup) clearOutbox(t *testing.T) {
	t.Helper()
	if s.db != nil {
		_, err := s.db.Exec("DELETE FROM outbox")
		require.NoError(t, err)
	}
}

// Scenario 1: Atomic write — business + outbox in same transaction.
//
// See: docs/OUTBOX_PATTERN.md §Solution
func TestOutbox_AtomicWrite_BusinessAndOutboxCommitTogether(t *testing.T) {
	s := setupOutboxTest(t)
	s.clearOutbox(t)
	ctx := context.Background()
	_ = ctx

	// TODO: trigger business operation
	// err := s.service.CreateOrder(ctx, CreateOrderCmd{OrderID: "order-1", ...})
	// require.NoError(t, err)

	// Assert outbox row created
	// rows, err := s.db.QueryContext(ctx, "SELECT event_type, published_at FROM outbox WHERE aggregate_id = $1", "order-1")
	// require.NoError(t, err)
	// defer rows.Close()
	// var eventType string
	// var publishedAt *time.Time
	// require.True(t, rows.Next(), "no outbox row found")
	// require.NoError(t, rows.Scan(&eventType, &publishedAt))
	// assert.Equal(t, "OrderCreated", eventType)
	// assert.Nil(t, publishedAt, "event must not be published yet")

	// Assert rollback atomicity — when business write fails, no outbox row created
	// err = s.service.CreateOrder(ctx, CreateOrderCmd{OrderID: "FAIL", ...})
	// assert.Error(t, err)
	// count := 0
	// s.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM outbox WHERE aggregate_id = $1", "FAIL").Scan(&count)
	// assert.Equal(t, 0, count, "outbox row created despite business write failure")
	t.Skip("TODO: implement atomic write test")
}

// Scenario 2: Relay publishes unpublished events.
//
// See: docs/OUTBOX_PATTERN.md §Outbox Relay
func TestOutbox_Relay_PublishesUnpublishedEvents(t *testing.T) {
	s := setupOutboxTest(t)
	s.clearOutbox(t)
	ctx := context.Background()
	_ = ctx

	// TODO: seed unpublished outbox row
	// _, err := s.db.ExecContext(ctx,
	//     `INSERT INTO outbox (event_id, event_type, payload, aggregate_type, aggregate_id, created_at)
	//      VALUES ($1, 'OrderCreated', $2::jsonb, 'order', 'order-1', NOW())`,
	//     uuid.New().String(), `{"orderId":"order-1"}`)
	// require.NoError(t, err)

	// TODO: run relay
	// err = s.relay.PublishPending(ctx)
	// require.NoError(t, err)

	// Assert event published to broker
	// events := s.brokerSpy.PublishedEvents()
	// require.Len(t, events, 1)
	// assert.Equal(t, "OrderCreated", events[0].EventType)
	t.Skip("TODO: implement relay publish test")
}

// Scenario 3: Relay marks events as published after successful publish.
//
// See: docs/OUTBOX_PATTERN.md §Outbox Relay
func TestOutbox_Relay_MarksEventsPublished(t *testing.T) {
	s := setupOutboxTest(t)
	s.clearOutbox(t)
	ctx := context.Background()
	_ = ctx

	// TODO: seed unpublished row, run relay, assert published_at set
	// eventID := uuid.New().String()
	// s.db.ExecContext(ctx, "INSERT INTO outbox (event_id, ...) VALUES ($1, ...)", eventID, ...)
	// s.relay.PublishPending(ctx)

	// var publishedAt *time.Time
	// s.db.QueryRowContext(ctx, "SELECT published_at FROM outbox WHERE event_id = $1", eventID).Scan(&publishedAt)
	// assert.NotNil(t, publishedAt, "published_at must be set after relay run")

	// Run relay again — broker must NOT receive duplicate
	// s.brokerSpy.Reset()
	// s.relay.PublishPending(ctx)
	// assert.Empty(t, s.brokerSpy.PublishedEvents(), "relay re-published already-published event")
	t.Skip("TODO: implement mark-published test")
}

// Scenario 4: Consumer deduplicates duplicate event delivery.
//
// See: docs/OUTBOX_PATTERN.md §Idempotent Event Processing
func TestOutbox_Consumer_DeduplicatesDuplicateEvent(t *testing.T) {
	s := setupOutboxTest(t)
	ctx := context.Background()
	_ = ctx

	// TODO: deliver same event twice, assert business logic ran once
	// evt := OutboxEvent{EventID: uuid.New().String(), EventType: "OrderCreated", ...}
	// s.consumer.Handle(ctx, evt)
	// s.consumer.Handle(ctx, evt) // re-delivery

	// assert.Equal(t, 1, s.orderProcessingCounter.Value())
	// assert.True(t, s.dedupStore.AlreadyProcessed(evt.EventID))
	t.Skip("TODO: implement deduplication test")
}

// Scenario 5: Cleanup deletes published rows older than TTL.
//
// See: docs/OUTBOX_PATTERN.md §Cleanup
func TestOutbox_Cleanup_DeletesPublishedRowsOlderThanTTL(t *testing.T) {
	s := setupOutboxTest(t)
	s.clearOutbox(t)
	ctx := context.Background()
	_ = ctx

	// TODO: seed old published row (> 7 days) and recent row (< 7 days)
	// _, err := s.db.ExecContext(ctx,
	//     `INSERT INTO outbox (event_id, event_type, payload, aggregate_type, aggregate_id, created_at, published_at)
	//      VALUES ($1, 'OrderCreated', '{}'::jsonb, 'order', 'old-1', NOW()-INTERVAL '8 days', NOW()-INTERVAL '8 days')`,
	//     uuid.New().String())
	// require.NoError(t, err)

	// _, err = s.db.ExecContext(ctx,
	//     `INSERT INTO outbox (..., created_at, published_at)
	//      VALUES (..., NOW()-INTERVAL '1 day', NOW()-INTERVAL '1 day')`,
	//     uuid.New().String())
	// require.NoError(t, err)

	// TODO: run cleanup
	// err = s.cleanup.DeleteExpired(ctx)
	// require.NoError(t, err)

	// Old row deleted
	// var count int
	// s.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM outbox WHERE aggregate_id = 'old-1'").Scan(&count)
	// assert.Equal(t, 0, count, "old published row was not cleaned up")

	// Recent row retained
	// s.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM outbox WHERE aggregate_id = 'recent-1'").Scan(&count)
	// assert.Equal(t, 1, count, "recent row was deleted prematurely")
	t.Skip("TODO: implement cleanup test")
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// pollDB polls a DB query expecting a non-zero count, for async relay tests.
func pollDB(t *testing.T, db *sql.DB, query string, args ...interface{}) bool {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		var count int
		if err := db.QueryRow(query, args...).Scan(&count); err == nil && count > 0 {
			return true
		}
		time.Sleep(100 * time.Millisecond)
	}
	return false
}
