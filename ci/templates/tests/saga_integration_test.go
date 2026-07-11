// saga_integration_test.go — Saga integration test template.
//
// Standards reference: docs/SAGA_PATTERN.md §Testing Sagas, §Required Tests
//
// HOW TO USE:
//  1. Copy to your service: cp .standards/ci/templates/tests/saga_integration_test.go \
//                              internal/saga/{your_saga}_integration_test.go
//  2. Replace all TODO markers with saga-specific implementations.
//  3. Add required deps: go get github.com/testcontainers/testcontainers-go
//                        go get github.com/stretchr/testify
//  4. Run: make test-integration  (or go test -tags integration ./internal/saga/...)
//
// Build tag "integration" prevents this from running during unit test pass.
// All 5 scenarios required by docs/SAGA_PATTERN.md §Required Tests are covered.

//go:build integration

package saga_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	// Testcontainers — add to go.mod:
	//   github.com/testcontainers/testcontainers-go
	//   github.com/testcontainers/testcontainers-go/modules/postgres
)

// TODO: replace with your saga types
// type SagaStatus string
// const (
//     SagaStatusCompleted  SagaStatus = "COMPLETED"
//     SagaStatusFailed     SagaStatus = "FAILED"
//     SagaStatusInProgress SagaStatus = "IN_PROGRESS"
// )

// testSetup holds all test dependencies. Replace with real types.
type sagaTestSetup struct {
	// TODO: orchestrator   *OrderSagaOrchestrator
	// TODO: stateStore     SagaStateStore
	// TODO: paymentStub    *PaymentServiceStub
	// TODO: inventoryStub  *InventoryServiceStub
}

func setupSagaTest(t *testing.T) *sagaTestSetup {
	t.Helper()
	// TODO: start Testcontainers Postgres (and message broker if needed)
	// ctx := context.Background()
	// pgContainer, err := postgres.RunContainer(ctx,
	//     testcontainers.WithImage("postgres:16"),
	//     postgres.WithDatabase("testdb"),
	//     postgres.WithUsername("test"),
	//     postgres.WithPassword("test"),
	// )
	// require.NoError(t, err)
	// t.Cleanup(func() { pgContainer.Terminate(ctx) })

	// TODO: init orchestrator, state store, stubs
	return &sagaTestSetup{}
}

// Scenario 1: Happy Path
// All saga steps complete. Final state = COMPLETED.
//
// See: docs/SAGA_PATTERN.md §Standard Saga: Order Processing (success path)
func TestSaga_HappyPath_AllStepsComplete(t *testing.T) {
	s := setupSagaTest(t)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	_ = s   // remove when implemented
	_ = ctx // remove when implemented

	// TODO: trigger saga
	// sagaID, err := s.orchestrator.Start(ctx, OrderCreatedEvent{OrderID: "order-1", ...})
	// require.NoError(t, err)

	// TODO: wait for completion
	// require.Eventually(t, func() bool {
	//     state, err := s.stateStore.Get(sagaID)
	//     return err == nil && state.Status == SagaStatusCompleted
	// }, 10*time.Second, 100*time.Millisecond, "saga did not complete")

	// assert.Equal(t, []string{"reserve_inventory", "process_payment"}, state.CompletedSteps)
	t.Skip("TODO: implement happy path test")
}

// Scenario 2: Failure at Step N → Compensation runs for steps 1..N-1.
//
// See: docs/SAGA_PATTERN.md §Compensating Transactions
func TestSaga_StepFailure_CompensationTriggered(t *testing.T) {
	s := setupSagaTest(t)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	_ = s
	_ = ctx

	// TODO: configure payment stub to fail
	// s.paymentStub.WillFail(ErrPaymentDeclined)

	// TODO: trigger saga
	// sagaID, err := s.orchestrator.Start(ctx, OrderCreatedEvent{OrderID: "order-2", ...})
	// require.NoError(t, err)

	// TODO: assert saga ends FAILED
	// require.Eventually(t, func() bool {
	//     state, _ := s.stateStore.Get(sagaID)
	//     return state.Status == SagaStatusFailed
	// }, 10*time.Second, 100*time.Millisecond)

	// TODO: assert inventory released (compensation ran)
	// assert.True(t, s.inventoryStub.ReleaseWasCalled("order-2"))
	// assert.False(t, s.paymentStub.RefundWasCalled("order-2")) // never started
	t.Skip("TODO: implement compensation test")
}

// Scenario 3: Step timeout → compensation triggered.
//
// See: docs/SAGA_PATTERN.md §Saga Timeout
func TestSaga_StepTimeout_CompensationTriggered(t *testing.T) {
	s := setupSagaTest(t)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	_ = s
	_ = ctx

	// TODO: configure payment stub to hang longer than saga step timeout
	// s.paymentStub.WillDelay(90 * time.Second) // > 60s payment timeout

	// sagaID, _ := s.orchestrator.Start(ctx, OrderCreatedEvent{OrderID: "order-3", ...})

	// require.Eventually(t, func() bool {
	//     state, _ := s.stateStore.Get(sagaID)
	//     return state.Status == SagaStatusFailed || state.Status == SagaStatusTimedOut
	// }, 90*time.Second, 500*time.Millisecond)

	// assert.True(t, s.inventoryStub.ReleaseWasCalled("order-3"))
	t.Skip("TODO: implement timeout test")
}

// Scenario 4: Duplicate event delivery → saga state unchanged.
//
// See: docs/IDEMPOTENCY.md §Message Consumers, docs/SAGA_PATTERN.md §Testing Sagas
func TestSaga_DuplicateEvent_Idempotent(t *testing.T) {
	s := setupSagaTest(t)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	_ = s
	_ = ctx

	// TODO: trigger saga once and wait for completion
	// sagaID, _ := s.orchestrator.Start(ctx, OrderCreatedEvent{OrderID: "order-4", ...})
	// require.Eventually(t, func() bool { ... completed ... }, 10*time.Second, 100*time.Millisecond)
	// stateAfterFirst, _ := s.stateStore.Get(sagaID)

	// TODO: re-deliver same event
	// s.orchestrator.Start(ctx, OrderCreatedEvent{OrderID: "order-4", ...}) // same ID

	// stateAfterSecond, _ := s.stateStore.Get(sagaID)
	// assert.Equal(t, stateAfterFirst.Version, stateAfterSecond.Version, "saga re-ran on duplicate")
	// assert.Equal(t, 1, s.inventoryStub.ReserveCallCount("order-4"), "reserve called more than once")
	t.Skip("TODO: implement idempotency test")
}

// Scenario 5: State store persistence — saga survives app restart.
//
// See: docs/SAGA_PATTERN.md §Saga State Store
func TestSaga_StateStorePersistence_SurvivesRestart(t *testing.T) {
	s := setupSagaTest(t)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	_ = s
	_ = ctx

	// TODO: start saga and advance to an intermediate step
	// sagaID, _ := s.orchestrator.Start(ctx, OrderCreatedEvent{OrderID: "order-5", ...})
	// require.Eventually(t, func() bool {
	//     state, _ := s.stateStore.Get(sagaID)
	//     return state.HasStep("reserve_inventory")
	// }, 5*time.Second, 100*time.Millisecond)

	// TODO: simulate restart by evicting in-memory cache
	// s.stateStore.EvictFromCache(sagaID)

	// TODO: reload from DB and assert state present
	// reloaded, err := s.stateStore.Get(sagaID)
	// require.NoError(t, err, "state not found after eviction — not persisted to DB")
	// assert.Equal(t, SagaStatusInProgress, reloaded.Status)
	// assert.Contains(t, reloaded.CompletedSteps, "reserve_inventory")
	t.Skip("TODO: implement state persistence test")
}

// ── Test helpers ──────────────────────────────────────────────────────────────

// waitFor polls condition fn until true or deadline exceeded.
// Use instead of time.Sleep for async assertions.
func waitFor(t *testing.T, timeout time.Duration, fn func() bool) bool {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if fn() {
			return true
		}
		time.Sleep(100 * time.Millisecond)
	}
	return false
}

// mustWaitFor calls waitFor and fails the test if condition never met.
func mustWaitFor(t *testing.T, timeout time.Duration, fn func() bool, msg string) {
	t.Helper()
	require.True(t, waitFor(t, timeout, fn), msg)
}
