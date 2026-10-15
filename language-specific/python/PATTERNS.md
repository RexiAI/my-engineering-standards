# Python — Patterns

Day-to-day patterns for Python backend services (FastAPI + Pydantic v2 +
SQLModel, managed with uv). The index ([`SKILL.md`](./SKILL.md)) sets the
build system, project structure, and always-rules; this file is the how.

Provenance labels (defined in [`SKILL.md`](./SKILL.md)): **[official]** =
backed by the official docs of the tool in question, **[convention]** = this
repo's team rule, **[ecosystem]** = third-party package guidance backed by
that package's own docs. All FastAPI claims below were verified against
<https://fastapi.tiangolo.com/> (FastAPI 0.143.1 baseline).

## Layered Architecture

**[convention]** The root `AGENTS.md`,
[`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md), and
`docs/CODING_CONVENTIONS.md §Base rules` (dependency rule) mandate:
controller → service → repository, dependencies point down, business logic
lives in services. In FastAPI terms:

| Layer | FastAPI component | Allowed to do |
|---|---|---|
| Controller | `APIRouter` module in `app/api/routers/` | Parse/validate input (Pydantic), call one service method, map result/error to HTTP |
| Service | plain class/function in `app/services/` | Business rules, orchestration across repositories, logging at method boundaries |
| Repository | class in `app/repositories/` | Data access via SQLModel/SQLAlchemy sessions; map entities ↔ domain |

**Where this guide is deliberately stricter than the FastAPI tutorial.** The
official tutorial commonly puts logic directly in route handlers — e.g. the
SQL tutorial's `create_hero` calls `session.add/commit/refresh` inside the
path operation **[official]**
(https://fastapi.tiangolo.com/tutorial/sql-databases/). That is fine for
learning and tiny apps, but it welds HTTP concerns to business logic: the
handler can't be unit-tested without the HTTP layer, and the domain rules
can't be reused by a second entry point (CLI, queue consumer).
**[convention]** This repo requires the handler to stay a thin adapter; the
tutorial shape is acceptable only in `mvp`-tier throwaway spikes.

```python
# app/services/item_service.py — no `fastapi` import anywhere in this file
class ItemService:
    def __init__(self, items: ItemRepository) -> None:
        self._items = items

    def create_item(self, data: ItemCreate) -> ItemPublic:
        if self._items.exists_by_name(data.name):
            raise ItemAlreadyExistsError(data.name)   # domain error, not HTTPException
        return self._items.insert(data)
```

```python
# app/api/routers/items.py — thin controller
router = APIRouter(prefix="/items", tags=["items"])

@router.post("/", status_code=201)
def create_item(
    payload: ItemCreate,
    service: ItemServiceDep,
) -> ItemPublic:
    return service.create_item(payload)
```

## Project Layout & Router Composition

**[official]** The official multi-file structure is an `app` package with
`main.py`, a `routers/` subpackage, and shared dependencies, composed with
`APIRouter` + `app.include_router()`
(https://fastapi.tiangolo.com/tutorial/bigger-applications/). `APIRouter` is
"a mini `FastAPI` class" supporting all the same parameters; `prefix`,
`tags`, `dependencies`, and `responses` declared on the router apply to all
its path operations (same page). Router-level `dependencies=[...]` are the
official way to require authentication for a whole group of path operations
without repeating it per route (same page). The same router can be included
multiple times under different prefixes (e.g. `/api/v1` and `/api/latest`)
(same page).

**[convention]** This repo's extension of that layout adds the layer
packages:

```python
# app/main.py
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routers import items, users
from app.core.logging import configure_logging


@asynccontextmanager
async def lifespan(app: FastAPI):
    configure_logging()
    yield  # startup before, shutdown after (see §Health & Lifespan)


def create_app() -> FastAPI:
    app = FastAPI(lifespan=lifespan)
    app.include_router(items.router, prefix="/v1")
    app.include_router(users.router, prefix="/v1")
    register_exception_handlers(app)   # see §Error Handling
    register_health_endpoints(app)     # see §Health & Lifespan
    return app


app = create_app()
```

- **[convention]** One router module per domain, one router per resource
  group; include with a URL version prefix (`/v1`) per
  `docs/ARCHITECTURE.md §API Versioning`.
- **[official]** Declare the app location once in `pyproject.toml` so the
  `fastapi` CLI and editor tooling find it
  (https://fastapi.tiangolo.com/tutorial/first-steps/ and
  https://fastapi.tiangolo.com/tutorial/bigger-applications/):

```toml
[tool.fastapi]
entrypoint = "app.main:app"
```

- **[official]** Every directory in the package gets an `__init__.py`
  (https://fastapi.tiangolo.com/tutorial/bigger-applications/).

## Pydantic v2 Schemas & Response Models

Pydantic v2 (https://docs.pydantic.dev/latest/) drives validation,
serialization, and OpenAPI generation. Rules:

- **[official] Separate DTOs from persistence entities.** Never return a
  table model directly, never accept one as input. The official SQL tutorial
  does exactly this with `HeroCreate` / `HeroPublic` / `HeroUpdate` — input
  and output models distinct from the `Hero(table=True)` entity, so
  `secret_name` can never leak into a response
  (https://fastapi.tiangolo.com/tutorial/sql-databases/). The Extra Models
  chapter's `UserIn` / `UserOut` / `UserInDB` split (plaintext password in,
  hashed password stored, password never out) is the canonical shape
  (https://fastapi.tiangolo.com/tutorial/extra-models/).
- **[official] Every path operation declares its output type** — either the
  `response_model` parameter or a return-type annotation. FastAPI uses it to
  validate, document, and filter: "even though the function returns more
  data, the response will only include the fields declared in the response
  model." When you return something that is *not* the declared type (a dict,
  a DB object), use the `response_model` parameter instead of the annotation
  (https://fastapi.tiangolo.com/tutorial/response-model/).
- **[convention] Wire format is camelCase**
  (`docs/CODING_CONVENTIONS.md §Naming`: JSON fields camelCase) while Python
  attributes stay snake_case — bridge with Pydantic's field-alias machinery:
  `alias`/`validation_alias`/`serialization_alias` per field
  (https://docs.pydantic.dev/latest/concepts/fields/) or the `AliasGenerator`
  dataclass "used by `alias_generator`" to generate them from a naming rule
  (https://docs.pydantic.dev/latest/api/alias_generators/), applied once via
  a shared `BaseModel` subclass in `app/schemas/base.py`.

```python
# app/schemas/item.py
from pydantic import BaseModel, ConfigDict


class ItemCreate(BaseModel):          # input DTO
    name: str
    price_cents: int                  # money in minor units — docs/CODING_CONVENTIONS.md


class ItemPublic(BaseModel):          # output DTO
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    price_cents: int
```

**[official]** `from_attributes=True` — a Pydantic `ConfigDict` option, also
available on `model_validate()` — builds the DTO from an arbitrary object's
attributes, e.g. a SQLModel/SQLAlchemy entity
(https://docs.pydantic.dev/latest/concepts/models/). The official SQL
tutorial instead derives its public model from a shared base class
(https://fastapi.tiangolo.com/tutorial/sql-databases/); either shape
satisfies the DTO/entity separation rule above.

## Dependency Injection

**[convention]** FastAPI's DI system is this repo's DI mechanism (root
`AGENTS.md`: "use dependency injection; avoid service locator or static
state"). Verified behavior **[official]**
(https://fastapi.tiangolo.com/tutorial/dependencies/):

- A dependency is any function taking the same parameters a path operation
  can; FastAPI calls it per request and injects the result. Dependencies can
  depend on dependencies — "a hierarchical tree of dependencies is built".
- Use the `Annotated` style (supported and recommended since 0.95.0), and
  store repeated annotations in type aliases — type information is preserved
  for editors and mypy.

```python
# app/api/deps.py
from typing import Annotated

from fastapi import Depends
from sqlmodel import Session

ItemServiceDep = Annotated[ItemService, Depends(get_item_service)]
SessionDep = Annotated[Session, Depends(get_session)]


def get_session():
    with Session(engine) as session:
        yield session


def get_item_service(session: SessionDep) -> ItemService:
    return ItemService(items=ItemRepository(session))
```

- **[convention]** Wiring is explicit and local: `get_item_service`
  constructs the service from the session — composition at the boundary, not
  a global registry. No module-level service singletons; anything that needs
  per-request state (sessions, current user) flows through `Depends`.
- **[official]** Dependencies with `yield` run their exit code *after* the
  response is sent (default `scope="request"`); pass
  `Depends(get_x, scope="function")` to close before the response instead. If
  you catch an exception inside a yield-dependency, re-raise it (bare
  `raise`) unless you raise an `HTTPException` — otherwise the client still
  gets a 500 but "the server will not have any logs" of what happened
  (https://fastapi.tiangolo.com/tutorial/dependencies/dependencies-with-yield/).
- **[official]** Overrides for testing: `app.dependency_overrides` is a plain
  dict — original dependency as key, replacement as value; FastAPI calls the
  override instead, wherever the dependency is used
  (https://fastapi.tiangolo.com/advanced/testing-dependencies/). This is how
  services get faked in tests — see [`TESTING.md`](./TESTING.md).

## Async vs Sync Handlers

Official decision rule **[official]** (https://fastapi.tiangolo.com/async/):

| Situation | Handler style |
|---|---|
| Library is called with `await` (async driver, httpx async) | `async def` |
| Library does blocking I/O with no `await` support ("currently the case for most database libraries") | plain `def` — FastAPI runs it in an external threadpool |
| No external communication at all | `async def` |
| Don't know | plain `def` ("if you just don't know, use normal `def`") |

- **[official]** `def` and `async def` handlers can be mixed freely in one
  app; the same rules apply to dependencies and sub-dependencies.
- **[official]** A plain `def` path operation "is run in an external
  threadpool that is then awaited" — it is not slow. **[convention]** Calling
  blocking I/O inside `async def` blocks the whole event loop; that is the
  one real footgun, and the reason for the always-rule.
- **[convention]** Sync SQLModel `Session` usage (the official tutorial's
  style) therefore belongs in plain `def` handlers.

## Database: SQLModel

What the official docs recommend, reported faithfully: the SQL tutorial uses
**SQLModel** — "built on top of SQLAlchemy and Pydantic… made by the same
author of FastAPI to be the perfect match for FastAPI applications that need
to use SQL databases" — while noting "FastAPI doesn't force you to use
anything" **[official]**
(https://fastapi.tiangolo.com/tutorial/sql-databases/). **[convention]**
This repo's default is SQLModel; plain SQLAlchemy when SQLModel's model layer
is too constraining (ADR required, `docs/ARCHITECTURE.md`).

- **[official]** The engine "holds the connections"; use one single `engine`
  object for the whole application (same page).
- **[official]** Session-per-request via a `yield` dependency — the
  tutorial's `get_session` / `SessionDep` pattern (same page; see §Dependency
  Injection above).
- **[official]** The tutorial uses SQLite (with
  `connect_args={"check_same_thread": False}`) and
  `SQLModel.metadata.create_all` for teaching; for production it points at a
  database server like PostgreSQL and at the official full-stack template
  (https://github.com/fastapi/full-stack-fastapi-template, linked from the
  same page). **[convention]** Production schema changes go through
  **Alembic** migrations (https://alembic.sqlalchemy.org/en/latest/, linked
  from the same page) **[ecosystem]**, never `create_all`.
- **[convention]** Repositories own all query code (`select`,
  `session.exec`); services receive entities and return DTOs; routers see
  neither.

## Configuration

Official pattern **[official]** (https://fastapi.tiangolo.com/advanced/settings/):
the `pydantic-settings` package (`uv add pydantic-settings`), a `Settings`
class subclassing `BaseSettings`, values read from **environment variables**
(case-insensitive: `APP_NAME` fills `app_name`), with full Pydantic type
conversion and validation. `.env` file support is built into pydantic-settings
via `SettingsConfigDict(env_file=".env")` but requires adding
`python-dotenv` (`uv add python-dotenv`) (same page).

```python
# app/core/config.py
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")
    app_name: str = "awesome-service"
    database_url: str
    jwt_secret: str            # required — startup fails loudly when missing


@lru_cache
def get_settings() -> Settings:
    return Settings()
```

- **[official]** Inject with `Annotated[Settings, Depends(get_settings)]`;
  `@lru_cache` reads the environment/dotenv once instead of per request; in
  tests, swap settings via `app.dependency_overrides[get_settings]` — the
  official page shows exactly this pattern (same page).
- **[convention]** `.env` stays gitignored (`docs/SECURITY.md §Secrets
  Management`); production reads from the secrets manager / environment,
  never a committed file.
- **[convention]** A missing required setting must fail at startup, not
  default silently — fail-closed per `docs/SECURITY.md §Internal and
  Machine-Facing Endpoints Fail Closed`.

## Security & Auth

**[official]** FastAPI ships security utilities in `fastapi.security`
implementing the OpenAPI security schemes: `apiKey` (query/header/cookie),
`http` (bearer, basic, digest), `oauth2` flows (`implicit`,
`clientCredentials`, `authorizationCode`, `password`), and `openIdConnect`
(https://fastapi.tiangolo.com/tutorial/security/). The official JWT recipe
(https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/):

- **[official]** `OAuth2PasswordBearer(tokenUrl="token")` used as a
  dependency yields the bearer token and answers 401 by itself when the
  `Authorization: Bearer` header is missing
  (https://fastapi.tiangolo.com/tutorial/security/first-steps/).
- **[official]** **PyJWT** for tokens: `uv add pyjwt`; add `pyjwt[crypto]`
  when using digital signature algorithms like RSA or ECDSA (oauth2-jwt page).
- **[official]** **pwdlib with Argon2** for password hashing: `uv add
  "pwdlib[argon2]"`; Argon2 is "the recommended algorithm"; pwdlib also
  supports bcrypt; passlib is recommended only for reading hashes generated
  by other/legacy systems (oauth2-jwt page).
- **[official]** Invalid credentials → `HTTP_401_UNAUTHORIZED` with a
  `WWW-Authenticate: Bearer` header (oauth2-jwt page).
- **[convention]** The repo-wide standard is RS256-signed JWTs with short
  expiry (`docs/SECURITY.md §Authentication`) — the tutorial's HS256 +
  `SECRET_KEY` is the minimum, not the target.

**[convention]** Repo rules layered on top (`docs/SECURITY.md`):

- Auth checks are dependencies (run before the handler body); role checks
  happen at the service boundary (`docs/SECURITY.md §Authorization`).
- Compare shared secrets in constant time (`hmac.compare_digest`), never `==`.
- Machine-facing endpoints fail closed when their credential is unconfigured
  (503/500, never open).
- Never forward an upstream provider's raw error body to your client — log it
  server-side, return a static generic error (`docs/SECURITY.md §Upstream
  Error Responses Must Not Reach the Client`).

## Error Handling

**[convention]** Repo philosophy (`docs/CODING_CONVENTIONS.md §Error Handling
Philosophy`, `docs/ARCHITECTURE.md §Error Handling`): expected failures
(validation, not-found, conflict) are domain values, not control flow;
exceptions are for infrastructure failure and programming errors;
translation to HTTP happens only at the boundary.

Python has no built-in Result type, so the Python mapping of that philosophy
is **[convention]**: a typed domain exception hierarchy raised by services
(the analogue of the Go guide's sentinel errors), converted to structured
JSON at the boundary. Keep the hierarchy closed and shallow; if you find
yourself branching on exception types in services, refactor per
`docs/CODING_CONVENTIONS.md §Base rules` ("generalize, don't special-case").

```python
# app/services/errors.py — domain errors; no HTTP status codes in here
class DomainError(Exception): ...
class ItemNotFoundError(DomainError): ...
class ItemAlreadyExistsError(DomainError): ...
```

FastAPI's boundary mechanisms (all **[official]** —
https://fastapi.tiangolo.com/tutorial/handling-errors/):

- `raise HTTPException(status_code=..., detail=...)` — **[convention]**
  inside routers and auth dependencies only. The tutorial raises it inside
  handlers with inline logic; this repo keeps that translation in one place.
  `detail` accepts any JSON-able value, not just `str` (same page).
- **Custom exception handlers** — `@app.exception_handler(ItemNotFoundError)`
  etc. — map domain errors to status + structured body, installed once in
  `main.py`. This is the Python equivalent of Java's `@ControllerAdvice` /
  Go's error middleware (**[convention]** mapping).
- FastAPI raises `RequestValidationError` on bad input and ships a default
  handler; override it with
  `@app.exception_handler(RequestValidationError)` to match your error
  schema. When registering handlers for HTTP errors, register against
  Starlette's `HTTPException` so internal/extension-raised errors are caught
  too; default handlers can be reused from `fastapi.exception_handlers`
  (same page).
- **[official]** The same page warns that `RequestValidationError` contains
  file/line information and echoing raw error content "could be leaking a bit
  of information about your system" — the official backing for the repo rule
  that raw internal details never reach the client.

**[convention]** Structured error body (consistent across all handlers):

```json
{"error": "item not found", "code": "ITEM_NOT_FOUND", "trace_id": "…"}
```

**[convention]** Unexpected exceptions get one catch-all handler that logs
the stack trace with the trace id and returns 500 with a static body — never
the raw exception text (`docs/SECURITY.md §Upstream Error Responses Must Not
Reach the Client`).

## Middleware & CORS

- **[official]** HTTP middleware: `@app.middleware("http")` on a function
  receiving `(request, call_next)`; modify the response before returning it.
  Middleware added later wraps earlier ones — outermost runs first on the
  request path, last on the response path
  (https://fastapi.tiangolo.com/tutorial/middleware/).
- **[official]** Class-based / third-party ASGI middlewares attach with
  `app.add_middleware(SomeMiddleware, ...)` — FastAPI (Starlette) provides
  this "simpler way… that makes sure that the internal middlewares handle
  server errors and custom exception handlers work properly"
  (https://fastapi.tiangolo.com/advanced/middleware/). Built-ins include
  `HTTPSRedirectMiddleware`, `TrustedHostMiddleware`, `GZipMiddleware` (same
  page).
- **[official] CORS**: `CORSMiddleware` from `fastapi.middleware.cors`; its
  defaults "are restrictive by default"; and none of `allow_origins`,
  `allow_methods`, `allow_headers` may be `["*"]` when
  `allow_credentials=True` (https://fastapi.tiangolo.com/tutorial/cors/).
  **[convention]** List origins explicitly; never wildcard with credentials.

**[convention]** Trace-id middleware (repo rule: structured logging with
trace IDs):

```python
# app/core/logging.py
import contextvars
import uuid

from fastapi import FastAPI

trace_id_var: contextvars.ContextVar[str] = contextvars.ContextVar("trace_id", default="")


def register_trace_id_middleware(app: FastAPI) -> None:
    @app.middleware("http")
    async def trace_id_middleware(request, call_next):
        trace_id = request.headers.get("traceparent") or uuid.uuid4().hex
        trace_id_var.set(trace_id)
        response = await call_next(request)
        response.headers["X-Trace-Id"] = trace_id_var.get()
        return response
```

**[official]** `contextvars` is stdlib and "natively supported in asyncio…
ready to be used without any extra configuration"
(https://docs.python.org/3/library/contextvars.html) — safe across concurrent
requests, unlike `threading.local`. **[convention]** At `production`
conformance tier, prefer FastAPI's built-in OpenTelemetry support — with
`fastapi[standard]`, "FastAPI provides OpenTelemetry support by default for
HTTP request traces, metrics, and logs", configured via environment
(`OTEL_EXPORTER_OTLP_ENDPOINT` etc.) or the `telemetry` dict, which can also
exclude paths like `/health`
(https://fastapi.tiangolo.com/advanced/opentelemetry/) — and propagate W3C
`traceparent` per [`docs/OBSERVABILITY.md`](../../docs/OBSERVABILITY.md).

## Structured Logging

**[convention]** Field set and levels are fixed by
[`docs/OBSERVABILITY.md §Structured Logging`](../../docs/OBSERVABILITY.md):
JSON logs with `timestamp, level, message, trace_id, span_id, service,
environment` + context, logged at **service** method boundaries (input,
result/error, duration). Implementation is stdlib `logging`
(https://docs.python.org/3/library/logging.html) with a JSON formatter
**[ecosystem/convention]** — no `print`, no unstructured text in production.

```python
logger = logging.getLogger("app.services.item_service")

def create_item(self, data: ItemCreate) -> ItemPublic:
    logger.info("create_item.start", extra={"name": data.name, "trace_id": trace_id_var.get()})
    item = self._items.insert(data)
    logger.info("create_item.done", extra={"item_id": item.id, "trace_id": trace_id_var.get()})
    return item
```

- **[convention]** Never log passwords, tokens, API keys, or PII
  (`docs/OBSERVABILITY.md §What NOT to Log`).

## Health & Lifespan

- **[convention]** `GET /` → simple ping; `GET /health` → deep check of
  **every** external dependency (database, cache, message broker), each
  contributing a named status, aggregated into one JSON body
  (`docs/ARCHITECTURE.md §Health Endpoints`, root `AGENTS.md`).
- **[convention]** Implement each dependency check behind one interface so
  adding a dependency forces adding its check:

```python
@router.get("/health")
def health(checks: Annotated[list[HealthCheck], Depends(get_health_checks)]):
    results = {c.name: c.check() for c in checks}
    ok = all(r == "UP" for r in results.values())
    return JSONResponse(status_code=200 if ok else 503, content=results)
```

- **[official]** Startup/shutdown uses the **lifespan** pattern: an
  `@asynccontextmanager` async function with `yield`, passed to
  `FastAPI(lifespan=...)`. The old `@app.on_event("startup")` style is
  documented under "Alternative Events (deprecated)", and "it's all
  `lifespan` or all events, not both"
  (https://fastapi.tiangolo.com/advanced/events/).
