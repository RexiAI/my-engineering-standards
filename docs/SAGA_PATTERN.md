# Saga Pattern Standards

## Philosophy

From Kleppmann: "Distributed transactions don't scale. Sagas break long-running processes into compensatable steps."

A saga is a sequence of local transactions. Each step publishes an event or triggers the next step. If a step fails, compensating transactions undo previous steps.

## Choreography vs Orchestration

### Choreography (Event-Driven)

Each service publishes events that trigger the next step. No central coordinator.

```
Order Service → "Order Created" → Payment Service → "Payment Completed" → Shipping Service
```

**Use when**: Few services (< 5), simple workflows, clear event flow.

### Orchestration (Command-Driven)

A central orchestrator tells each service what to do and tracks state.

```
Order Orchestrator → Create Order → Process Payment → Ship Order
                                       ↓ (failure)
                                 Refund Payment → Cancel Order
```

**Use when**: Complex workflows, many services, need compensation logic, long-running with state persistence.

## Standard Saga: Order Processing

### Choreography (Simple)

```
1. Order Service: Create order (PENDING status)
   → emits "OrderCreated"
2. Inventory Service: Reserve items
   → emits "InventoryReserved" or "InventoryFailed"
3. Payment Service: Charge customer
   → emits "PaymentCompleted" or "PaymentFailed"
4. Order Service: On PaymentCompleted → set CONFIRMED
   On PaymentFailed → set FAILED → emit "OrderCancelled"
5. Inventory Service: On OrderCancelled → release reservation
```

### Orchestration (Complex)

```
Orchestrator state machine:

           → InventoryReserved → PaymentCompleted → ShippingRequested → [DONE]
          /                        |
OrderCreated → InventoryFailed ────→ CancelOrder [FAIL]
                                    PaymentFailed ──→ RefundStarted → [FAIL]
```

## Compensating Transactions

| Step | Forward Action | Compensating Action |
|------|---------------|-------------------|
| Create Order | `INSERT order (PENDING)` | `UPDATE order SET status = CANCELLED` |
| Reserve Inventory | `UPDATE stock SET qty = qty - 1` | `UPDATE stock SET qty = qty + 1` |
| Process Payment | `INSERT payment + charge()` | `refund()` via payment provider |
| Ship Order | `UPDATE order SET status = SHIPPED` | `cancelShipment()` (may not be possible) |

**Critical**: Compensating actions must be idempotent and reliable. If a compensating action fails, it must be retried (manual intervention after N retries).

## Implementation

### Orchestrator (Stateful)

```java
@Component
public class OrderSagaOrchestrator {
    private final SagaStateStore stateStore;

    @SagaHandler
    public void handle(OrderCreatedEvent event) {
        SagaState state = new SagaState(event.orderId());
        stateStore.save(state);

        // Step 1: Reserve inventory
        send("inventory.reserve", new ReserveItemsCommand(event.orderId(), event.items()));
    }

    @SagaHandler
    public void onInventoryReserved(InventoryReservedEvent event) {
        // Step 2: Process payment
        SagaState state = stateStore.get(event.orderId());
        state.stepCompleted("inventory");
        send("payment.charge", new ChargePaymentCommand(event.orderId(), event.amount()));
    }

    @SagaHandler
    public void onPaymentFailed(PaymentFailedEvent event) {
        // Compensate: cancel order
        send("order.cancel", new CancelOrderCommand(event.orderId()));
        // Compensate: release inventory
        send("inventory.release", new ReleaseItemsCommand(event.orderId()));
    }

    @SagaHandler
    public void onPaymentCompleted(PaymentCompletedEvent event) {
        SagaState state = stateStore.get(event.orderId());
        state.stepCompleted("payment");
        state.markCompleted();
        stateStore.save(state);
    }
}
```

### Saga State Store

Persist saga state so it survives restarts:

```json
{
    "sagaId": "order_123_2024-01-01",
    "type": "ORDER_PROCESSING",
    "status": "IN_PROGRESS",
    "startedAt": "2024-01-01T12:00:00Z",
    "steps": [
        { "name": "reserve_inventory", "status": "COMPLETED" },
        { "name": "process_payment", "status": "PENDING" }
    ],
    "compensationStack": ["cancel_order", "release_inventory"]
}
```

### Saga Timeout

| Step | Timeout | Action on Timeout |
|------|---------|-------------------|
| Inventory reservation | 30s | Cancel order, release any held items |
| Payment processing | 60s | Cancel order, release inventory |
| Shipping request | 120s | Alert operations, continue monitoring |

## When NOT to Use Sagas

- Short-lived operations that can use a local transaction (single DB)
- Operations where isolation is required (use 2PC with short-lived locks)
- Operations where compensation is destructive (use at-least-once delivery instead)

## Testing Sagas

| Test Type | What to Verify |
|-----------|----------------|
| Unit | Each step handler processes events correctly |
| Integration | Compensation is triggered on step failure |
| E2E | Complete saga runs end-to-end with message broker |
| Chaos | Saga survives service crash mid-step (recovery from state store) |

## See Also

- `docs/OUTBOX_PATTERN.md` — reliable event publishing for saga steps
- `docs/IDEMPOTENCY.md` — deduplication for saga step retries
- `docs/RESILIENCE.md` — retry and timeout for saga handlers
