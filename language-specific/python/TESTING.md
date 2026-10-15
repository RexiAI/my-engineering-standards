# Python — Testing

The layered test strategy (unit / acceptance / integration / E2E) and what
each layer proves is defined in [`docs/TESTING.md`](../../docs/TESTING.md) and
inherited here — this file covers the *tools* and the *patterns* for the
Python/FastAPI stack. Provenance labels (**[official]** / **[convention]** /
**[ecosystem]**) are defined in [`SKILL.md`](./SKILL.md).

## Runner & Configuration

- **pytest** is the runner: it "makes it easy to write small, readable tests,
  and can scale to support complex functional testing" **[official]**
  (https://docs.pytest.org/en/stable/). It is also what the official FastAPI
  testing flow uses: `uv add pytest`, then `uv run pytest` auto-detects
  `test_*` files and functions **[official]**
  (https://fastapi.tiangolo.com/tutorial/testing/). pytest itself requires
  Python 3.10+ **[official]** (https://docs.pytest.org/en/stable/).
- **[convention]** Config lives in `pyproject.toml`:

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-q --strict-markers"
```

- **[convention]** `tests/` mirrors the source layout
  (`docs/TESTING.md §Unit Tests`: "test files mirror source package
  structure"): `tests/unit/services/test_item_service.py` tests
  `app/services/item_service.py`.
- **[convention]** Name tests after scenario + outcome:
  `test_create_item_rejects_duplicate_name`.

## Layer → Tooling Map

**[convention]** — layers inherited from
[`docs/TESTING.md`](../../docs/TESTING.md); tools are this stack's picks:

| Layer | Tools for this stack |
|---|---|
| Unit | pytest + plain fakes / stdlib `unittest.mock` for repositories; no HTTP, no DB |
| Acceptance | same frameworks, named to the scenario ID (`AC-NNN-NN`, spec pipeline — `docs/SPEC_PIPELINE.md`) |
| Integration | `TestClient` (or `httpx.AsyncClient`) against the real app + in-memory SQLite; outbound HTTP stubbed with `httpx.MockTransport` **[ecosystem]** (https://www.python-httpx.org/advanced/transports/ — "accepts a handler function, which can be used to map requests onto pre-determined responses") |
| E2E | full service in Docker compose; poll `GET /health` for readiness (never a fixed sleep — `docs/TESTING.md §Readiness polling, never a fixed sleep`) |

In-memory alternatives follow `docs/TESTING.md §Integration Tests`
(SQLite `:memory:` is that table's in-memory SQL pick). The SQLModel/SQLite
engine flags used by the official tutorial — in-memory SQLite with
`connect_args={"check_same_thread": False}` — are **[official]**
(https://fastapi.tiangolo.com/tutorial/sql-databases/). The official FastAPI
pointer for database testing is the SQLModel docs' testing section
**[official]** (https://fastapi.tiangolo.com/how-to/testing-database/, which
links https://sqlmodel.tiangolo.com/tutorial/fastapi/tests/).

## TestClient (default) vs httpx.AsyncClient

The official recommendation, verified:

- **[official] `TestClient` is the default.** It comes from Starlette, is
  based on HTTPX, and is used from *normal* `def` test functions with plain
  pytest — "the testing functions are normal `def`, not `async def`… This
  allows you to use pytest directly without complications." Requires
  `uv add httpx`. (https://fastapi.tiangolo.com/tutorial/testing/)
- **[official]** `TestClient` takes JSON-convertible data (`dict`, via
  `json=`), not Pydantic model instances; convert first with
  `jsonable_encoder` (same page).
- **[official]** Using `TestClient` as a context manager runs the app's
  lifespan handler around the test — "If you want the `TestClient` to run the
  `lifespan` handler, you will need to use the `TestClient` as a context
  manager" (https://starlette.dev/testclient/, linked from the FastAPI
  testing page).
- **[official] `httpx.AsyncClient` is for tests that must themselves be
  `async`** — e.g. when the test setup awaits an async database library. The
  `TestClient`'s internal machinery "doesn't work anymore when we're using it
  inside asynchronous test functions", so the official Async Tests page uses
  `AsyncClient` with `ASGITransport` and the AnyIO pytest plugin marker
  (https://fastapi.tiangolo.com/advanced/async-tests/):

```python
import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.mark.anyio
async def test_root():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        response = await ac.get("/")
    assert response.status_code == 200
```

- **[official]** Caveat from the same page: unlike the context-managed
  `TestClient`, `AsyncClient` does **not** trigger lifespan events; use
  `LifespanManager` from asgi-lifespan
  (https://github.com/florimondmanca/asgi-lifespan, linked from that page)
  **[ecosystem]** when the test needs startup/shutdown.

**[convention]** House rule: prefer sync `def` tests + `TestClient`; reach
for `AsyncClient` + `pytest.mark.anyio` only when the test body genuinely
needs `await`. Requests never leave the process in either mode — no live
server needed.

## Isolating Services: dependency_overrides

**[official]** `app.dependency_overrides` is a plain dict — original
dependency (the function object) as key, replacement as value; FastAPI calls
the override instead, wherever the dependency is used. Reset by assigning an
empty dict (https://fastapi.tiangolo.com/advanced/testing-dependencies/).
The official settings chapter uses the same mechanism to swap `Settings` in
tests (https://fastapi.tiangolo.com/advanced/settings/). This is the seam for
every layer **[convention]**:

```python
# unit-ish integration test: real routers, fake service
def fake_item_service() -> ItemService:
    return ItemService(items=FakeItemRepository())


def test_create_item_conflict(client: TestClient):
    app.dependency_overrides[get_item_service] = fake_item_service
    try:
        r = client.post("/v1/items/", json={"name": "dupe", "priceCents": 100})
        assert r.status_code == 409
        assert r.json()["code"] == "ITEM_ALREADY_EXISTS"
    finally:
        app.dependency_overrides = {}   # never leak overrides across tests
```

- **[convention]** Override the **outermost dependency you want to fake** —
  the service for router tests, the session/engine for repository
  integration tests.
- **[convention]** Always clear overrides (fixture teardown, below); a leaked
  override silently rewrites unrelated tests.
- **[convention]** Mock at boundaries, assert on behavior, not invocations
  (`docs/TESTING.md §Test Behavior, Not Implementation`).

## Fixture Strategy

All **[convention]** unless noted:

- **No base classes.** Composition via fixtures and helpers, never an
  `AbstractBaseTestSuite` (`docs/CODING_CONVENTIONS.md §Base rules`:
  composition over inheritance, in tests too).
- `client` fixture (function-scoped) builds the app and yields a
  `TestClient`, clearing `dependency_overrides` in teardown:

```python
# tests/conftest.py
import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    with TestClient(app) as c:   # context manager runs lifespan (official — see above)
        yield c
    app.dependency_overrides = {}
```

- One in-memory SQLite engine/session fixture per test (function scope —
  isolation over speed tricks); override `get_session` to point at it.
- Settings: construct `Settings(...)` explicitly per test instead of mutating
  process env; inject via `dependency_overrides[get_settings]` (the official
  pattern — https://fastapi.tiangolo.com/advanced/settings/).
- **Test Data Builders** for anything with >3 fields — the composable builder
  pattern from `docs/TESTING.md §Test Data (Builder Pattern)`:

```python
class ItemFactory:
    def __init__(self) -> None:
        self.name = "default-item"
        self.price_cents = 100

    def with_name(self, name: str) -> "ItemFactory":
        self.name = name
        return self

    def build(self) -> ItemCreate:
        return ItemCreate(name=self.name, price_cents=self.price_cents)
```

## Coverage & Quality Gates

- **[convention]** Coverage is an advisory, PR-only signal — not a blocking
  gate (`docs/TESTING.md §Code Coverage`). Use `uv run pytest --cov=app`
  (pytest-cov, dev dependency **[ecosystem]**).
- **[convention]** Unit tests for business logic are required at every
  conformance tier (`docs/CONFORMANCE_TIERS.md §What stays at mvp regardless
  of tier`).
- **[convention] Mutation testing applies at the `production` conformance
  tier** ([`docs/CONFORMANCE_TIERS.md`](../../docs/CONFORMANCE_TIERS.md),
  `docs/TESTING.md §Mutation Testing`). That section standardizes
  PiTest/Gremlins/Stryker for Java/Go/JS. **ADR 0006 selected `mutmut` as the
  Python mutator**
  ([`docs/adr/0006-python-rust-gate-coverage.md`](../../docs/adr/0006-python-rust-gate-coverage.md)),
  with the config and the ≥80% / zero-mutant-fails gate in
  `ci/templates/mutmut-pyproject.toml`. Like the other mutation assets it is
  opt-in and periodic, not per-PR. `docs/TESTING.md §Mutation Testing`'s tool
  table still lacks a Python row — a docs follow-up, not a gate change.

## Layer Boundaries (inherited)

**[convention]** — from [`docs/TESTING.md`](../../docs/TESTING.md):

- Unit tests touch no network, filesystem service, or database.
- Integration tests cross exactly one architectural boundary (HTTP → app with
  in-memory DB, or repository → in-memory DB) with everything else faked.
- E2E tests run the real containerized service and exercise full HTTP paths
  against it, one script shared by CI and local runs
  (`docs/TESTING.md §One script, run by both CI and local dev`).

See [`docs/TESTING.md`](../../docs/TESTING.md) for the full layer definitions,
flake-retry policy, and the "tests that encode a defect" procedure — all
apply unchanged to this stack.
