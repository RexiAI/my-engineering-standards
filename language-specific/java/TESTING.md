# Java — Testing

The layered strategy (unit / acceptance / integration / E2E) and the
requirements for each layer are defined in the root
[`docs/TESTING.md`](../../docs/TESTING.md) and inherited here. This file covers
the Java tools and the shape of a test in this house.

Framework set: **JUnit 5 · Mockito · AssertJ**. No other test framework is
added without a reason a reviewer can check.

## Layer boundaries

| Layer | Loads Spring context? | Annotations | Purpose |
|---|---|---|---|
| Unit | **No** | `@ExtendWith(MockitoExtension.class)` | One class, mocked boundaries, branch-level behaviour |
| Acceptance | No | same as unit, named with the scenario ID | Proves one task's behaviour end to end within the unit boundary |
| Integration | **Yes** | `@SpringBootTest` (+ `@AutoConfigureMockMvc`) | Real wiring: MVC, serialization, JPA, transactions |

`@SpringBootTest` in a unit test is a **defect**, not a preference. It turns a
millisecond test into a multi-second one, hides the boundary under test, and
makes the suite pass for reasons the test never asserted.

## Shape

Every test is Given-When-Then, in that order, with the observable values named
`actual` / `expected`:

```java
@Test
void shouldReturnEmptySummaryWhenNoOrdersInWindow() {
    // Given
    var repository = mock(OrderRepository.class);
    when(repository.findByCreatedAtBetween(any(), any())).thenReturn(List.of());
    var service = new OrderService(repository);
    var window = new DateRange(from, to);

    // When
    var actual = service.summarize(window);

    // Then
    var expected = Summary.empty();
    assertThat(actual).isEqualTo(expected);
}
```

- Setup lives in the test, not in a distant `@BeforeEach`. A reader should not
  have to scroll to understand the precondition.
- One scenario per test. Two asserts on two behaviours is two tests.
- Test data comes from a builder (`docs/TESTING.md §Test Data`), never from
  object defaults — a default that changes must not silently change the test.

## Case selection

Select from the code's branches and validation rules, not from data volume.

| Include | Exclude |
|---|---|
| Every branch: happy path, each guard, each catch/fallback | Collection sizes (0, 1, 3 items are usually one branch) |
| Each validation rule, at its boundary (null, empty, max, max+1) | Getters, records, framework-generated code |
| Each side effect the method owns (save, publish, log-and-swallow) | Private methods as a test target |
| Each documented failure contract (exception type, message, error code) | Combinations already covered by another test |

Test through the public API. If behaviour is reachable only via a private
method, that is a design signal, not a reason to widen the test's reach.

## Mocks

- Mock **boundaries**: repositories, HTTP clients, clocks, message brokers.
- Do not mock value objects, DTOs, or the class under test.
- `when(...)` arguments are exact where they matter; `any()` only where the
  argument is genuinely irrelevant to the assertion.
- Capture DTO arguments with `ArgumentCaptor`, then assert the fields. `any()`
  on a DTO asserts only that *some* object was passed — usually not what the
  test claims.

```java
var captor = ArgumentCaptor.forClass(OrderEvent.class);
verify(publisher).publish(captor.capture());
assertThat(captor.getValue().status()).isEqualTo(Status.CONFIRMED);
```

## Assertions

- AssertJ, fluent, one conceptual assertion per test.
- Assert on the value, not on `toString()`.
- For collections: `containsExactly` / `containsExactlyInAnyOrder` rather than
  a size check followed by index lookups.
- For exceptions: `assertThatThrownBy(...).isInstanceOf(X.class).hasMessage(...)`
  — assert the type *and* the part of the message the caller depends on.

## No logic in tests

- Expected values are literals. Do not recompute the expectation with the same
  arithmetic the production code uses; that asserts the implementation against
  itself.
- No loops, branches, or helper-framework machinery inside a test body. Table
  tests are for many rows of the *same* assertion, not for hiding control flow.

## Logs and time

- Prefer asserting a returned result over asserting a log line. Log assertions
  belong to the small number of behaviours whose contract *is* the log
  (audit trails, swallowed-error warnings): use `OutputCaptureExtension` there.
- Inject `Clock` and assert on `Instant`; never `Thread.sleep` to wait for a
  timestamp or an async side effect.

## Mutation testing

Conformance tier `production` (see `docs/CONFORMANCE_TIERS.md`). PiTest runs
under the `mutation` profile; target mutation coverage is ≥ 80%
(`docs/TESTING.md §Mutation Testing`). A green suite at 100% branch coverage
with a low mutation score is a weak suite — the pipeline's Mutation Runner
stage exists to say so with a number instead of an opinion.

## What this file is not

- Not a replacement for `docs/TESTING.md` — the layer definitions and the
  acceptance/scenario rules live there.
- Not a licence to add test dependencies. `spring-boot-starter-test` covers
  JUnit 5, Mockito, AssertJ, and the Spring test utilities; anything beyond it
  needs a stated reason.
