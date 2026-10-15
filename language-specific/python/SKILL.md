---
name: python
description: Python backend standards: project shape (Python 3.10+, uv, FastAPI, Pydantic v2, SQLModel/SQLAlchemy), lint/type/test commands (ruff, mypy, pytest), layered router → service → repository rules, and pointers to PATTERNS.md / TESTING.md. Use whenever a child repo uses Python — trigger on FastAPI, Pydantic, uv, ruff, pytest, or any *.py backend work.
license: See repo root
applyTo: "**/pyproject.toml, **/*.py"
---

# Python Standards

Entry point for the Python backend stack. Repo-wide rules (conventional
commits, layered testing, secrets handling, PR-only merges) are inherited from
the root `AGENTS.md` and are not restated here.

Ground truth: **FastAPI 0.143.1** (MIT, created by Sebastián Ramírez) requires
**Python >= 3.10**; the official docs hub is <https://fastapi.tiangolo.com/>.
Labels used below and in the siblings: **[official]** = backed by the official
docs of the tool/framework in question, **[convention]** = this repo's team
rule, **[ecosystem]** = third-party package guidance backed by that package's
own docs.

## Build System

- **Language**: Python >= 3.10 is the floor — FastAPI 0.143.1 requires it, and
  the official tutorial code targets "Python 3.10+" (`X | None` syntax,
  `Annotated`) **[official]**
  <https://fastapi.tiangolo.com/tutorial/first-steps/>. Pydantic and pytest
  also require 3.10+ **[official]** (<https://docs.pydantic.dev/latest/>,
  <https://docs.pytest.org/en/stable/>). Current stable CPython documentation
  is 3.15 and the official version list marks **3.10 as EOL**
  **[official]** <https://docs.python.org/3/>. **[convention]** Declare
  `requires-python = ">=3.10"` in `pyproject.toml` as the floor; new services
  should target a supported release (3.11+), and code must run on every
  version from the declared floor up. uv uses a compatible installed
  interpreter or downloads one **[official]**
  <https://fastapi.tiangolo.com/tutorial/>.
- **Package / project manager**: **uv**. The official FastAPI install flow is
  `uv init awesome-project --bare` then `uv add "fastapi[standard]"`
  **[official]** <https://fastapi.tiangolo.com/tutorial/>. uv is "an extremely
  fast Python package and project manager, written in Rust", a single tool
  replacing pip, pip-tools, pipx, poetry, pyenv, and virtualenv, 10–100x
  faster than pip, with a universal lockfile **[official]**
  <https://docs.astral.sh/uv/>. Dev tooling goes in the `dev` dependency group
  via `uv add --dev` (PEP 735, synced by default) **[official]**
  <https://docs.astral.sh/uv/concepts/projects/dependencies/>.
- **Web framework**: FastAPI 0.143.1. `fastapi[standard]` pulls the default
  optional dependencies (including `fastapi-cloud-cli`); use
  `fastapi[standard-no-fastapi-cloud-cli]` or bare `fastapi` when those are
  unwanted **[official]** <https://fastapi.tiangolo.com/tutorial/>.
- **Validation / serialization**: Pydantic v2 (v2.14.1 at the time of writing)
  — "the most widely used data validation library for Python", core validation
  written in Rust **[official]** <https://docs.pydantic.dev/latest/>.
- **ORM**: SQLModel — "built on top of SQLAlchemy and Pydantic… made by the
  same author of FastAPI", and what the official SQL tutorial uses; FastAPI
  "doesn't force you to use anything" **[official]**
  <https://fastapi.tiangolo.com/tutorial/sql-databases/>. Plain SQLAlchemy is
  acceptable; a switch is an ADR (**[convention]**, `docs/ARCHITECTURE.md`).
- **Config lives in `pyproject.toml`** **[convention, all tools support it
  officially]**: dependencies, `[tool.ruff]`
  (<https://docs.astral.sh/ruff/configuration/>), `[tool.mypy]`
  (<https://mypy.readthedocs.io/en/stable/>), `[tool.pytest.ini_options]`, and
  `[tool.fastapi] entrypoint` so the CLI and editor tooling find the app
  **[official]** <https://fastapi.tiangolo.com/tutorial/first-steps/>.
  `uv.lock` is committed — it records exact versions for reproducible
  installs **[official]** <https://fastapi.tiangolo.com/tutorial/>.

## Commands

| Command | What it does |
|---|---|
| `uv sync` | Create / update `.venv` from `pyproject.toml` + `uv.lock` |
| `uv add <pkg>` / `uv add --dev <pkg>` | Add runtime / dev-group dependency, re-lock |
| `uv lock` | Re-resolve dependencies into `uv.lock` |
| `uv run fastapi dev` | Dev server with reload (reads `[tool.fastapi] entrypoint`) |
| `uv run fastapi run` | Production server |
| `uv run pytest` | Run the test suite (official FastAPI testing flow) |
| `uv run ruff check .` | Lint (add `--fix` to autofix) |
| `uv run ruff format .` | Format (`--check` = fail if unformatted — CI gate) |
| `uv run mypy app` | Static type check |

`fastapi dev` / `fastapi run` and the entrypoint config come from
<https://fastapi.tiangolo.com/tutorial/first-steps/>; `uv add pytest` +
`uv run pytest` from <https://fastapi.tiangolo.com/tutorial/testing/>;
`ruff format --check` from <https://docs.astral.sh/ruff/configuration/>. All
**[official]**.

## Project Structure

The official multi-file layout is an `app` package with `main.py`, routers,
and shared dependencies, one `__init__.py` per directory **[official]**
<https://fastapi.tiangolo.com/tutorial/bigger-applications/>. This repo
extends it with explicit `services/` and `repositories/` packages because the
root `AGENTS.md` mandates the layered architecture **[convention]** — see
`PATTERNS.md`.

```
awesome-project/
├── pyproject.toml             # deps + [tool.ruff]/[tool.mypy]/[tool.pytest.ini_options]/[tool.fastapi]
├── uv.lock                    # committed — reproducible installs
├── .env                       # local secrets/config — gitignored (docs/SECURITY.md §Secrets Management)
├── app/                       # Python package (__init__.py in every directory)
│   ├── __init__.py
│   ├── main.py                # FastAPI app factory, lifespan, router wiring, exception handlers, /health
│   ├── core/
│   │   ├── config.py          # pydantic-settings Settings (env vars)
│   │   └── logging.py         # structured JSON logging setup + trace-id contextvar
│   ├── api/
│   │   ├── deps.py            # shared dependencies: DB session, current user, service wiring
│   │   └── routers/           # thin controller layer — one APIRouter module per domain
│   │       ├── items.py
│   │       └── users.py
│   ├── services/              # business logic — no `fastapi` imports
│   ├── repositories/          # persistence — SQLModel/SQLAlchemy data access only
│   ├── schemas/               # Pydantic v2 request/response DTOs (ItemCreate, ItemPublic, …)
│   └── models/                # SQLModel table models (persistence entities)
└── tests/
    ├── unit/                  # services & repositories against fakes
    ├── integration/           # HTTP + real (in-memory) infrastructure
    └── e2e/                   # Dockerized full service
```

## Linting & Formatting

- **ruff** for linting *and* formatting — and nothing else. Do not run black,
  isort, flake8, or pylint alongside it. Justified from the official docs
  **[official]** <https://docs.astral.sh/ruff/>: ruff is "an extremely fast
  Python linter and code formatter, written in Rust", "10-100x faster than
  existing linters (like Flake8) and formatters (like Black)", with "drop-in
  parity with Flake8, isort, and Black"; it replaces those tools plus
  pydocstyle, pyupgrade, and autoflake; it reads `pyproject.toml`; it is made
  by Astral (the uv authors); and FastAPI itself is listed among its users.
  One toolchain, one config, no overlapping rule sets — also the repo rule
  "prefer stdlib, justify each dependency" (**[convention]**,
  `docs/CODING_CONVENTIONS.md §Base rules`).
- **mypy** for static typing — "Mypy is a static type checker for Python… it
  finds bugs in your programs without even running them" **[official]**
  <https://mypy.readthedocs.io/en/stable/>.
- **[convention]** config in `pyproject.toml`
  (<https://docs.astral.sh/ruff/configuration/>):
  `[tool.ruff.lint] select = ["E", "F", "I", "UP", "B", "C90"]` (isort,
  pyupgrade, bugbear, McCabe — all native ruff rule sets),
  `[tool.ruff.lint.mccabe] max-complexity = 6` (ruff's default is 10; 6
  enforces `docs/CODING_CONVENTIONS.md §Design Principles` — the `C901` rule
  and its `max-complexity` setting are documented at
  <https://docs.astral.sh/ruff/settings/>), `[tool.mypy] strict = true`,
  `[tool.pytest.ini_options] testpaths = ["tests"]`.
- **bandit** for SAST — "a tool designed to find common security issues in
  Python code… processes each file, builds an AST from it, and runs
  appropriate plugins against the AST nodes" **[official]**
  <https://bandit.readthedocs.io/en/latest/> (PyCQA, Apache-2.0, has a
  dedicated CI/CD section). Run `bandit -r src/` in CI. `docs/SECURITY.md` is
  the rule source; bandit is the mechanical check. **[convention]**
- **mutmut** for mutation testing at the `production` conformance tier
  (`../../docs/CONFORMANCE_TIERS.md`) — "a mutation testing system for Python"
  **[official]** <https://mutmut.readthedocs.io/en/latest/>: `mutmut run`,
  review survivors with `mutmut browse`, emit CI stats with
  `mutmut export-cicd-stats`; configure `[tool.mutmut] source_paths = ["src/"]`.
  Two constraints that matter in CI: it **requires fork support** (POSIX only —
  Windows needs WSL), and mutmut 3+ mutates only code *inside functions*
  (mutmut 2 has a different execution model). **[official]**
  A mutation gate **must fail when zero mutants were scored** — a score computed
  over nothing is a false pass. That is the same defect class as
  `scripts/check-code-principles.sh` exiting clean when it scans no files (see
  `../../docs/OFFICIAL_REFERENCES.md` §Findings). **[convention]**
  No Python mutation CI template exists in `ci/templates/` yet; adding one is a
  gate-catalog change requiring an ADR.

## Typing

- **[convention]** Type hints on every public function; `mypy --strict` must
  pass in CI (strict mode is an official mypy feature **[official]**,
  <https://mypy.readthedocs.io/en/stable/>).
- Modern syntax: `X | None` not `Optional[X]`, builtin generics (`list[str]`)
  — the style the official FastAPI examples use for Python 3.10+
  **[official]**; ruff's `UP` (pyupgrade) rules enforce the upgrade
  automatically **[official]** <https://docs.astral.sh/ruff/>.
- `Annotated[T, Depends(...)]` for FastAPI dependencies — supported and
  recommended since FastAPI 0.95.0; store repeated annotations in type
  aliases so tooling keeps working **[official]**
  <https://fastapi.tiangolo.com/tutorial/dependencies/>.

## Always-Rules

- **Layering** **[convention]**: routers (thin, = controller layer) → services
  (business logic) → repositories (persistence). Routers never import
  repositories; services never import `fastapi`. This is stricter than the
  FastAPI tutorial, which commonly puts logic in route handlers — rationale in
  `PATTERNS.md §Layered Architecture` (root `AGENTS.md`,
  `docs/ARCHITECTURE.md`, `docs/CODING_CONVENTIONS.md §Base rules` dependency
  rule).
- **DI via `Depends`** — wire services at the API boundary; no service
  locator, no module-level mutable singletons. FastAPI's dependency-injection
  system calls your dependency per request and injects the result
  **[official]** <https://fastapi.tiangolo.com/tutorial/dependencies/>;
  no-locator/no-static-state is the repo rule (**[convention]**, root
  `AGENTS.md`).
- **async vs sync** **[official]**
  <https://fastapi.tiangolo.com/async/>: `async def` when awaiting
  async-capable libraries; plain `def` for blocking/sync-only libraries ("this
  is currently the case for most database libraries") — FastAPI runs `def`
  handlers in an external threadpool; "if you just don't know, use normal
  `def`". Never call blocking I/O inside `async def` **[convention]**.
- **Pydantic v2 models at every API boundary** — separate input/output DTOs
  (`ItemCreate` ≠ `ItemPublic`); declare output via `response_model` or a
  return-type annotation so FastAPI filters the response to exactly the
  declared fields **[official]**
  <https://fastapi.tiangolo.com/tutorial/response-model/>,
  <https://fastapi.tiangolo.com/tutorial/extra-models/>.
- **Errors handled at the boundary** **[convention]**: services raise typed
  domain errors; routers/exception handlers translate to structured JSON
  responses — `docs/CODING_CONVENTIONS.md §Error Handling Philosophy`,
  `PATTERNS.md §Error Handling` (mechanisms are official:
  <https://fastapi.tiangolo.com/tutorial/handling-errors/>).
- **`GET /health`** deep-checks all external dependencies; `GET /` is a simple
  ping (**[convention]**, `docs/ARCHITECTURE.md §Health Endpoints`).
- **Config from environment variables** via pydantic-settings; `.env` support
  needs `python-dotenv`; secrets never in code, never committed **[official]**
  <https://fastapi.tiangolo.com/advanced/settings/>, **[convention]**
  `docs/SECURITY.md §Secrets Management`.
- **Structured logging with trace IDs** at service-method boundaries
  (**[convention]**, `docs/OBSERVABILITY.md §Structured Logging`,
  `PATTERNS.md §Structured Logging`).
- **Naming** **[convention]**: PEP 8 — `snake_case` functions/variables/
  modules, `PascalCase` classes, `UPPER_SNAKE_CASE` constants (this overrides
  the camelCase method row of `docs/CODING_CONVENTIONS.md §Naming` for Python;
  enforce with ruff's pep8-naming rules). JSON wire fields stay camelCase per
  that same table, mapped with Pydantic's `alias_generator` config and
  `AliasGenerator` **[official]**
  (<https://docs.pydantic.dev/latest/concepts/fields/>,
  <https://docs.pydantic.dev/latest/api/alias_generators/>).
- **Complexity ≤6 per function**, methods <20 lines, files <500 lines
  (**[convention]**, `docs/CODING_CONVENTIONS.md §Design Principles`;
  enforced mechanically by ruff `C901`).
- **Tests**: pytest; sync `TestClient` tests are the default — full rules in
  [`TESTING.md`](./TESTING.md).

## Read in Order

1. [`PATTERNS.md`](./PATTERNS.md) — layering, APIRouter composition, Pydantic
   DTOs, DI, async rules, SQLModel, configuration, auth/security, error
   handling, middleware, logging, health & lifespan.
2. [`TESTING.md`](./TESTING.md) — pytest, `TestClient` vs
   `httpx.AsyncClient`, `dependency_overrides`, fixtures, layer mapping.
3. [`docs/TESTING.md`](../../docs/TESTING.md) and
   [`docs/SECURITY.md`](../../docs/SECURITY.md) — the repo-wide rules this
   guide instantiates for Python.

## Adoption

Child repos opt in by adding `language-specific/python/SKILL.md` to their
`opencode.json` `instructions` array, alongside any other language-specific
guides they use.

**No Python saga/outbox CI gate templates exist yet, and detection does not scan
Python.** `scripts/detect-saga-outbox.sh` filters changed files to
`\.(java|go|ts|js|sql|xml)$` (line 79) and allows only
`*.java|*.go|*.ts|*.js|*.sql|*.xml` for migration names (line 69). A FastAPI
service carrying saga or outbox code therefore leaves `SAGA_DETECTED` and
`OUTBOX_DETECTED` false, and every downstream gate (`check-saga-timeouts.sh`,
`check-saga-tests.sh`, `lint-outbox-schema.sh`, `check-outbox-relay.sh`)
silently skips. **That is a coverage hole, not a passing gate** — apply
`docs/SAGA_PATTERN.md` and `docs/OUTBOX_PATTERN.md` by review until a Python gate
exists. `ci/templates/` covers Java, Go and Node only; adding a Python gate
changes the gate catalog and requires an ADR first
(`docs/GOVERNANCE.md §ADR Requirement`). This directory is deliberately
docs-only — track it as a follow-up, don't improvise a gate script.
