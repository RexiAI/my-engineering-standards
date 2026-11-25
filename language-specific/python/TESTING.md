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
| E2E | full service (live uvicorn or Docker compose) against real sandbox providers; `e2e` marker, excluded by default — see §E2E below |

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

## E2E

Python and FastAPI repos use this section for end-to-end tests. The agentic E2E
framework (`skills/e2e-testing/SKILL.md`) is the standard for TS/Node and
React Native only. Python E2E stays pytest-driven: the real service runs
against real **sandbox** providers (payment test mode, telephony test
credentials, messaging sandboxes). The layer definition, cadence, and flake
policy are inherited from `docs/TESTING.md §E2E Tests`.

### Marker, excluded from the default run

**[official]** pytest custom markers are registered in config and selected or
deselected with `-m`
(https://docs.pytest.org/en/stable/example/markers.html). With
`--strict-markers`, an unregistered marker is an error
(https://docs.pytest.org/en/stable/how-to/mark.html).

**[convention]** Every E2E test carries `@pytest.mark.e2e` and lives under
`tests/e2e/`. A plain `pytest` never runs it:

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-q --strict-markers -m 'not e2e'"
markers = ["e2e: hits real sandbox providers; run with `pytest -m e2e`"]
```

Select it explicitly with `uv run pytest -m e2e tests/e2e`. When `-m` appears
on the command line, it wins over the `-m` in `addopts`, because the later
option overrides the earlier one.

### Credentials: env vars, skip with a reason

- **[convention]** Sandbox credentials come only from environment variables:
  CI secrets in CI, and the gitignored `.env` locally (`docs/SECURITY.md
  §Secrets Management`). They never come from a committed file.
- **[official]** `pytest.skip(reason)` skips the test and shows the reason in
  the report (https://docs.pytest.org/en/stable/how-to/skipping.html).
- **[convention]** When a credential is missing, the test skips. The reason
  names the **variable** and never its value. Never print, log, or assert on a
  secret value.

```python
# tests/e2e/conftest.py
import os

import pytest


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        pytest.skip(f"{name} not set — sandbox E2E skipped")
    return value
```

- **[convention]** In a CI job whose purpose is E2E, a skip is a
  misconfiguration. Set `E2E_REQUIRED=1` there, and have `require_env` call
  `pytest.fail` instead of `pytest.skip` when it is set. A silent all-skip run
  is a false green.

### Cleanup: yield fixtures, always

**[official]** In a `yield` fixture, the code after `yield` is teardown. It
runs even when the test fails, but it does not run if the fixture itself
raised before `yield`
(https://docs.pytest.org/en/stable/how-to/fixtures.html#yield-fixtures-recommended).
`request.addfinalizer` is the alternative.

**[convention]** Every sandbox resource a test creates (customer, phone
number, webhook subscription, tenant) gets torn down by the fixture that
created it. Teardown is best effort: log failures and do not raise them, so
one leaked resource does not mask the real assertion failure.

```python
import logging
import uuid

log = logging.getLogger(__name__)


@pytest.fixture
def run_id() -> str:
    return f"e2e-{uuid.uuid4().hex[:12]}"   # unique per test: re-runs never collide


@pytest.fixture
def sandbox_customer(payments_client, run_id):
    customer = payments_client.create_customer(email=f"{run_id}@example.test",
                                               metadata={"e2e_run": run_id})
    yield customer
    try:
        payments_client.delete_customer(customer.id)
    except Exception:                         # teardown must not mask the test result
        log.warning("e2e cleanup failed", extra={"resource": customer.id})
```

- **[convention]** Tag every created resource with the `run_id` (metadata,
  name prefix). A scheduled sweeper can then delete orphans older than N
  hours, which catches anything a killed runner never tore down.
- **[convention]** Test data is unique per run (`run_id`), and every assertion
  is scoped to that data, so a re-run is idempotent. Never assert on global
  counts in a shared sandbox account.

### Inbound events: signed webhook simulation

Providers sign the webhooks they deliver. Twilio sends `X-Twilio-Signature`,
an HMAC-SHA1 over the full URL plus the sorted POST params, keyed by the auth
token **[official]**
(https://www.twilio.com/docs/usage/webhooks/webhooks-security). Meta sends
`X-Hub-Signature-256`, an HMAC-SHA256 of the raw body, keyed by the app secret
**[official]**
(https://developers.facebook.com/docs/graph-api/webhooks/getting-started).

**[convention]** E2E tests deliver inbound events by **signing them exactly as
the provider would**, using the sandbox secret and stdlib `hmac`. Never turn
off signature verification for tests. A test that bypasses the check proves
nothing about the check. Also send one tampered payload and assert `403`.

```python
import hashlib
import hmac


def meta_signature(app_secret: str, raw_body: bytes) -> str:
    digest = hmac.new(app_secret.encode(), raw_body, hashlib.sha256).hexdigest()
    return f"sha256={digest}"


def test_inbound_message_is_accepted(live_client, run_id):
    secret = require_env("META_APP_SECRET")
    body = build_whatsapp_event(text=f"hola {run_id}").encode()
    r = live_client.post("/v1/webhooks/meta", content=body,
                         headers={"X-Hub-Signature-256": meta_signature(secret, body),
                                  "Content-Type": "application/json"})
    assert r.status_code == 200
```

Prefer the provider SDK's own validator when one exists, for example
`twilio.request_validator.RequestValidator`, to compute the expected
signature. That keeps the test's signing aligned with the server's checking.

### In-process client vs live server

| Need | Use |
|---|---|
| Real providers, app in-process, no network hop to the app | `TestClient` as a context manager (runs lifespan — see §TestClient above) |
| Real HTTP: a provider calls back into you, a browser drives the UI, middleware or proxy behavior | live `uvicorn` subprocess or the Docker compose stack, driven by `httpx.Client(base_url=..., timeout=...)` |

**[convention]** Start the live server from a session fixture on a free port.
Poll `GET /health` until it returns 200, with a bounded deadline. Never use a
fixed `sleep` (`docs/TESTING.md §Readiness polling, never a fixed sleep`).
Terminate the server in teardown, and attach its log on failure.

```python
import subprocess
import time

import httpx


def wait_ready(url: str, deadline_s: float = 30.0) -> None:
    end = time.monotonic() + deadline_s
    while time.monotonic() < end:
        try:
            if httpx.get(url, timeout=2.0).status_code == 200:
                return
        except httpx.TransportError:
            pass
        time.sleep(0.25)                      # poll interval, not a readiness guess
    raise TimeoutError(f"{url} not ready after {deadline_s}s")


@pytest.fixture(scope="session")
def live_client(tmp_path_factory):
    port = 8765                               # or pick a free port via socket.bind(("", 0))
    log_path = tmp_path_factory.mktemp("server") / "uvicorn.log"
    with open(log_path, "wb") as log_file:
        proc = subprocess.Popen(["uv", "run", "uvicorn", "app.main:app", "--port", str(port)],
                                stdout=log_file, stderr=subprocess.STDOUT)
        try:
            wait_ready(f"http://127.0.0.1:{port}/health")
            with httpx.Client(base_url=f"http://127.0.0.1:{port}", timeout=10.0) as c:
                yield c
        finally:
            proc.terminate()
            proc.wait(timeout=10)
```

uvicorn's command-line options are documented at
https://www.uvicorn.org/settings/ **[official]**.

### Timeouts, retries, artifacts

- **[official]** httpx applies a 5-second default timeout. Set the timeout
  explicitly on every client anyway
  (https://www.python-httpx.org/advanced/timeouts/).
- **[convention]** Give every test an upper bound so a hung sandbox call fails
  the test instead of the job. pytest-timeout **[ecosystem]**
  (https://github.com/pytest-dev/pytest-timeout) does this with
  `timeout = 120` under `[tool.pytest.ini_options]`, and the CI job has its own
  `timeout-minutes`.
- **[convention]** Do not retry until green. If a rerun plugin is used
  (pytest-rerunfailures **[ecosystem]**,
  https://github.com/pytest-dev/pytest-rerunfailures), it is per test, starts
  at `reruns=1`, and has a comment naming the transient condition it absorbs
  (`docs/TESTING.md §Bounded, justified flake retry`). A sandbox 4xx is never
  retried.
- **[convention]** On failure, keep the evidence: `--junitxml`, the live
  server log, and Playwright traces. Upload them as CI artifacts (see the
  template below), and scrub secrets first.

### Browser flows (optional): Playwright for Python

**[official]** `pytest-playwright` provides a `page` fixture and the
`--browser`, `--headed`, and `--tracing retain-on-failure` options
(https://playwright.dev/python/docs/test-runners). Traces open in the trace
viewer (https://playwright.dev/python/docs/trace-viewer). Use web-first
assertions such as `expect(page.get_by_role(...)).to_be_visible()`, which
retry until a timeout, instead of sleeps
(https://playwright.dev/python/docs/test-assertions). Mark browser tests
`e2e` as well, and run them against the live server fixture.

### CI: scheduled/manual, never per PR

**[convention]** E2E runs weekly and on `workflow_dispatch`. It is not a
per-PR gate (`docs/TESTING.md §E2E Tests`, `docs/DEPLOYMENT.md §Quality
Gates`). Copy `ci/templates/child-ci-python-e2e.yml`. Sandbox secrets map into
`env:` from repository secrets (`docs/SECURITY.md §CI/CD Supply Chain`). They
never appear in `run:` bodies, and the job never runs on fork-triggered
events.

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
