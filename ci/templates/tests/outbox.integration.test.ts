/**
 * Outbox integration test template — TypeScript/Node.js
 *
 * Standards reference: docs/OUTBOX_PATTERN.md §Required Tests
 *
 * HOW TO USE:
 *  1. Copy to your service:
 *       cp .standards/ci/templates/tests/outbox.integration.test.ts \
 *          src/__tests__/integration/{your-service}-outbox.integration.test.ts
 *  2. Replace all TODO markers with service-specific implementations.
 *  3. Add deps: npm install --save-dev @testcontainers/postgresql testcontainers
 *  4. Run: npm run test:integration
 *
 * Vitest (preferred) and Jest are both supported.
 * All 5 scenarios required by docs/OUTBOX_PATTERN.md §Required Tests are covered.
 */

// ── Test runner import (choose one) ──────────────────────────────────────────
import { describe, it, expect, beforeEach, afterAll } from "vitest";
// import { describe, it, expect, beforeEach, afterAll } from "@jest/globals";

// TODO: import your service, outbox relay, broker spy, dedup store, and DB client
// import { OrderService } from "../../src/order/order.service";
// import { OutboxRelay } from "../../src/outbox/outbox.relay";
// import { MessageBrokerSpy } from "../stubs/message-broker-spy";
// import { DedupStore } from "../../src/outbox/dedup-store";
// import { sql } from "../../src/db/client";   // or your DB client

// ── Setup ─────────────────────────────────────────────────────────────────────

// let pgContainer: StartedPostgreSqlContainer;
// let orderService: OrderService;
// let outboxRelay: OutboxRelay;
// let brokerSpy: MessageBrokerSpy;
// let dedupStore: DedupStore;

// beforeAll(async () => {
//   pgContainer = await new PostgreSqlContainer("postgres:16").start();
//   // TODO: run migrations, init services using container connection string
// });

// afterAll(async () => {
//   await pgContainer?.stop();
// });

beforeEach(async () => {
  // TODO: clear outbox table and reset broker spy between tests
  // await sql`DELETE FROM outbox`;
  // brokerSpy.reset();
});

/** Poll DB row count until > 0 or timeout. For relay async assertions. */
async function pollDbCount(
  queryFn: () => Promise<number>,
  timeoutMs = 5_000,
  intervalMs = 100
): Promise<boolean> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if ((await queryFn()) > 0) return true;
    await new Promise((r) => setTimeout(r, intervalMs));
  }
  return false;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe("Outbox Integration", () => {
  // Scenario 1: Atomic write — business + outbox in same transaction.
  //
  // See: docs/OUTBOX_PATTERN.md §Solution
  it("business write and outbox insert are atomic", async () => {
    // TODO: trigger business operation
    // await orderService.createOrder({ orderId: "order-1", ... });

    // Assert outbox row created (not yet published)
    // const rows = await sql`SELECT event_type, published_at FROM outbox WHERE aggregate_id = 'order-1'`;
    // expect(rows).toHaveLength(1);
    // expect(rows[0].event_type).toBe("OrderCreated");
    // expect(rows[0].published_at).toBeNull();

    // Assert rollback atomicity — when business write fails, no outbox row
    // await expect(orderService.createOrder({ orderId: "FAIL", ... })).rejects.toThrow();
    // const failRows = await sql`SELECT COUNT(*) FROM outbox WHERE aggregate_id = 'FAIL'`;
    // expect(Number(failRows[0].count)).toBe(0);
    expect.fail("TODO: implement atomic write test");
  });

  // Scenario 2: Relay publishes unpublished events.
  //
  // See: docs/OUTBOX_PATTERN.md §Outbox Relay
  it("relay publishes unpublished outbox events", async () => {
    // TODO: seed unpublished row
    // await sql`
    //   INSERT INTO outbox (event_id, event_type, payload, aggregate_type, aggregate_id, created_at)
    //   VALUES (gen_random_uuid(), 'OrderCreated', ${{ orderId: "order-1" }}::jsonb, 'order', 'order-1', NOW())
    // `;

    // TODO: trigger relay
    // await outboxRelay.publishPending();

    // Assert event published to broker
    // expect(brokerSpy.publishedEvents()).toHaveLength(1);
    // expect(brokerSpy.publishedEvents()[0].eventType).toBe("OrderCreated");
    expect.fail("TODO: implement relay publish test");
  });

  // Scenario 3: Relay marks events as published after successful publish.
  //
  // See: docs/OUTBOX_PATTERN.md §Outbox Relay
  it("relay marks events as published — no re-publish on next run", async () => {
    // TODO: seed row, run relay, assert published_at set
    // const [{ event_id: eventId }] = await sql`
    //   INSERT INTO outbox (event_id, event_type, payload, aggregate_type, aggregate_id, created_at)
    //   VALUES (gen_random_uuid(), 'OrderCreated', '{}'::jsonb, 'order', 'order-1', NOW())
    //   RETURNING event_id
    // `;
    // await outboxRelay.publishPending();

    // const [row] = await sql`SELECT published_at FROM outbox WHERE event_id = ${eventId}`;
    // expect(row.published_at).not.toBeNull();

    // Run again — no duplicate publish
    // brokerSpy.reset();
    // await outboxRelay.publishPending();
    // expect(brokerSpy.publishedEvents()).toHaveLength(0);
    expect.fail("TODO: implement mark-published test");
  });

  // Scenario 4: Consumer deduplicates duplicate event delivery.
  //
  // See: docs/OUTBOX_PATTERN.md §Idempotent Event Processing
  it("consumer handles duplicate event delivery exactly once", async () => {
    // TODO: deliver same event twice
    // const event = { eventId: crypto.randomUUID(), eventType: "OrderCreated", ... };
    // await consumer.handle(event);
    // await consumer.handle(event); // re-delivery

    // Assert business logic ran once
    // expect(orderProcessingCounter.value).toBe(1);
    // expect(await dedupStore.alreadyProcessed(event.eventId)).toBe(true);
    expect.fail("TODO: implement deduplication test");
  });

  // Scenario 5: Cleanup deletes published rows older than TTL (7 days).
  //
  // See: docs/OUTBOX_PATTERN.md §Cleanup
  it("cleanup deletes published rows older than 7 days", async () => {
    // TODO: seed old (> 7 days) and recent (< 7 days) published rows
    // await sql`
    //   INSERT INTO outbox (event_id, event_type, payload, aggregate_type, aggregate_id, created_at, published_at)
    //   VALUES (gen_random_uuid(), 'OrderCreated', '{}'::jsonb, 'order', 'old-1',
    //           NOW() - INTERVAL '8 days', NOW() - INTERVAL '8 days')
    // `;
    // await sql`
    //   INSERT INTO outbox (..., created_at, published_at)
    //   VALUES (..., NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day')
    // `;

    // TODO: run cleanup
    // await outboxCleanup.deleteExpired();

    // Old row deleted
    // const [{ count: oldCount }] = await sql`SELECT COUNT(*) FROM outbox WHERE aggregate_id = 'old-1'`;
    // expect(Number(oldCount)).toBe(0);

    // Recent row retained
    // const [{ count: recentCount }] = await sql`SELECT COUNT(*) FROM outbox WHERE aggregate_id = 'recent-1'`;
    // expect(Number(recentCount)).toBe(1);
    expect.fail("TODO: implement cleanup test");
  });
});
