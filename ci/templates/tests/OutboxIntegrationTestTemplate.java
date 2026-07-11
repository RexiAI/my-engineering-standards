package com.mycompany.myservice.outbox;

import org.awaitility.Awaitility;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Outbox integration test template.
 *
 * Standards reference: docs/OUTBOX_PATTERN.md §Required Tests
 *
 * HOW TO USE:
 *   1. Copy to src/test/java/.../{YourService}OutboxIntegrationTest.java
 *   2. Replace all TODO markers with your service-specific implementations.
 *   3. Add Testcontainers + Awaitility deps (same as SagaIntegrationTestTemplate.java).
 *   4. Run with: mvn test -Dtest={YourService}OutboxIntegrationTest
 *
 * All 5 scenarios required by docs/OUTBOX_PATTERN.md §Required Tests are covered.
 */
@SpringBootTest
@Testcontainers
class OutboxIntegrationTestTemplate {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16")
            .withDatabaseName("testdb")
            .withUsername("test")
            .withPassword("test");

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private TransactionTemplate txTemplate;

    // TODO: inject your service and outbox relay
    // @Autowired private OrderService orderService;
    // @Autowired private OutboxRelay outboxRelay;

    // TODO: inject message broker spy/stub
    // @Autowired private MessageBrokerSpy brokerSpy;

    // TODO: inject consumer dedup store
    // @Autowired private DedupStore dedupStore;

    @BeforeEach
    void resetOutbox() {
        jdbc.update("DELETE FROM outbox");
        // TODO: reset broker spy and dedup store
        // brokerSpy.reset();
        // dedupStore.clear();
    }

    // ── Scenario 1: Atomic Write — Business + Outbox in Same Transaction ───────
    /**
     * Business write and outbox row must commit atomically.
     * If business write succeeds but outbox insert fails → both rollback.
     * If business write fails → outbox row must NOT be created.
     *
     * See: docs/OUTBOX_PATTERN.md §Solution —
     *   "BEGIN TRANSACTION → INSERT business → INSERT outbox → COMMIT"
     */
    @Test
    void businessWriteAndOutboxInsert_areAtomic() {
        // TODO: trigger business operation that writes to outbox
        // orderService.createOrder(new CreateOrderCommand("order-1", ...));

        // Assert outbox row created in same transaction
        // List<Map<String, Object>> rows = jdbc.queryForList(
        //     "SELECT * FROM outbox WHERE aggregate_id = 'order-1'");
        // assertThat(rows).hasSize(1);
        // assertThat(rows.get(0)).containsKey("event_type");
        // assertThat(rows.get(0).get("event_type")).isEqualTo("OrderCreated");
        // assertThat(rows.get(0).get("published_at")).isNull(); // not yet published

        // TODO: test rollback atomicity — when business write fails, no outbox row
        // assertThatThrownBy(() -> orderService.createOrder(new CreateOrderCommand("FAIL", ...)))
        //     .isInstanceOf(SomeException.class);
        // assertThat(jdbc.queryForList("SELECT * FROM outbox WHERE aggregate_id = 'FAIL'"))
        //     .isEmpty();
        throw new UnsupportedOperationException("TODO: implement atomic write test");
    }

    // ── Scenario 2: Relay Publishes Unpublished Events ─────────────────────────
    /**
     * OutboxRelay.publishPending() must pick up all rows where published_at IS NULL
     * and publish them to the message broker.
     *
     * See: docs/OUTBOX_PATTERN.md §Outbox Relay
     */
    @Test
    void relay_publishesUnpublishedEvents() {
        // TODO: seed unpublished outbox rows
        // String eventId = UUID.randomUUID().toString();
        // jdbc.update(
        //     "INSERT INTO outbox (event_id, event_type, payload, aggregate_type, aggregate_id, created_at) " +
        //     "VALUES (?, 'OrderCreated', ?::jsonb, 'order', 'order-1', NOW())",
        //     eventId, "{\"orderId\":\"order-1\"}");

        // TODO: trigger relay
        // outboxRelay.publishPending();

        // Assert event was published to broker
        // assertThat(brokerSpy.getPublishedEvents()).hasSize(1);
        // assertThat(brokerSpy.getPublishedEvents().get(0).getEventType()).isEqualTo("OrderCreated");
        throw new UnsupportedOperationException("TODO: implement relay publish test");
    }

    // ── Scenario 3: Relay Marks Events as Published ────────────────────────────
    /**
     * After publishing, the relay must update published_at on each event row.
     * Events must not be re-published on subsequent relay runs.
     *
     * See: docs/OUTBOX_PATTERN.md §Outbox Relay (polling relay code example)
     */
    @Test
    void relay_marksEventsPublished_afterSuccessfulPublish() {
        // TODO: seed unpublished row
        // String eventId = UUID.randomUUID().toString();
        // jdbc.update("INSERT INTO outbox (...) VALUES (...)", eventId, ...);

        // TODO: run relay
        // outboxRelay.publishPending();

        // Assert published_at is now set
        // Map<String, Object> row = jdbc.queryForMap(
        //     "SELECT * FROM outbox WHERE event_id = ?", eventId);
        // assertThat(row.get("published_at")).isNotNull();

        // Run relay again — broker must NOT receive duplicate
        // outboxRelay.publishPending();
        // assertThat(brokerSpy.getPublishedEvents()).hasSize(1); // still 1, not 2
        throw new UnsupportedOperationException("TODO: implement mark-published test");
    }

    // ── Scenario 4: Consumer Deduplicates Duplicate Events ────────────────────
    /**
     * Relay may re-publish an event if it crashes after publishing but before
     * marking published_at. Consumer must deduplicate using event_id.
     *
     * See: docs/OUTBOX_PATTERN.md §Idempotent Event Processing
     */
    @Test
    void consumer_deduplicatesDuplicateEvent() {
        // TODO: process the same event twice via consumer
        // var event = new OutboxEvent(UUID.randomUUID().toString(), "OrderCreated", ...);
        // consumer.handle(event);
        // consumer.handle(event); // re-delivery

        // Assert business logic ran exactly once (not twice)
        // assertThat(orderProcessingCounter.get()).isEqualTo(1);
        // assertThat(dedupStore.alreadyProcessed(event.getEventId())).isTrue();
        throw new UnsupportedOperationException("TODO: implement deduplication test");
    }

    // ── Scenario 5: Cleanup Deletes Old Published Rows ─────────────────────────
    /**
     * Published rows older than TTL (7 days by default) must be deleted by the
     * cleanup job to prevent table bloat.
     *
     * See: docs/OUTBOX_PATTERN.md §Cleanup
     */
    @Test
    void cleanup_deletesPublishedRowsOlderThanTtl() {
        // TODO: seed old published rows (published > 7 days ago)
        // jdbc.update(
        //     "INSERT INTO outbox (event_id, event_type, payload, aggregate_type, aggregate_id, " +
        //     "                   created_at, published_at) " +
        //     "VALUES (gen_random_uuid(), 'OrderCreated', '{}'::jsonb, 'order', 'old-1', " +
        //     "        NOW() - INTERVAL '8 days', NOW() - INTERVAL '8 days')");

        // Seed a recent published row (< 7 days) — must NOT be deleted
        // jdbc.update(
        //     "INSERT INTO outbox (..., created_at, published_at) " +
        //     "VALUES (..., NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day')");

        // TODO: trigger cleanup job
        // outboxCleanup.deleteExpired();

        // Old row deleted
        // assertThat(jdbc.queryForList("SELECT * FROM outbox WHERE aggregate_id = 'old-1'"))
        //     .isEmpty();

        // Recent row retained
        // assertThat(jdbc.queryForList("SELECT * FROM outbox WHERE aggregate_id = 'recent-1'"))
        //     .hasSize(1);
        throw new UnsupportedOperationException("TODO: implement cleanup test");
    }
}
