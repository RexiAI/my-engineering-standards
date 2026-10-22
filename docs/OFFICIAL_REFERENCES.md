# Official Documentation References

Authoritative upstream sources behind every `language-specific/<stack>/` guide in
this repo, with the exact versions those guides were distilled against.

**Purpose.** The guides in `language-specific/` are *paraphrased* house standards,
not mirrors of upstream docs. This index is the audit trail: it records which
official documentation was consulted, at which version, on which date, so a
reviewer can re-verify any claim and so the guides can be refreshed deliberately
when upstream moves.

**Rule.** Any URL cited as *authority for a specific claim* in a
`language-specific/` guide must have been actually read, and must appear here.
A section may additionally list a canonical upstream *reading set* — but only
with an explicit provenance note saying whether the content was read or merely
verified to resolve. Never present an unread URL as though it backed a claim.

**Retrieval date:** 2026-10-15

---

## Version pins

These are the versions the current guides were written against. A guide that
describes behaviour from a different major version is a defect.

| Stack | Pinned version | Floor / runtime | Upstream authority |
|---|---|---|---|
| Angular | **v22** (`^22.0.0`, released 2026-06-03; docs build `v22.2.2`) | — | [Versioning and releases](https://angular.dev/reference/releases) |
| Ionic Framework | **v9** | — | [Ionic docs home](https://ionicframework.com/docs) |
| Capacitor | **v8** | — | [Capacitor docs home](https://capacitorjs.com/docs) |
| NestJS | **`@nestjs/core` 12.1.3** | Node `>= 20`, ESM (`"type": "module"`) | [npm registry](https://registry.npmjs.org/@nestjs/core/latest) |
| FastAPI | **0.143.1** | Python `>= 3.10` | [PyPI JSON API](https://pypi.org/pypi/fastapi/json) |
| Rust | **1.99.0** (2026-10-01) | Edition **2024** | [Release announcement](https://blog.rust-lang.org/releases/latest/) · [releases.rs](https://releases.rs/) |

### Support windows worth knowing

- **Angular**: 24-month support window (12 months Active + 12 months LTS). As of
  v22 the major-release cadence changed from 6 months to **12 months**.
  `^22.0.0` Active → 2027-06, LTS → 2028-06. `^21.0.0` and `^20.0.0` are LTS.
  **Angular v2 through v19 are no longer supported** — guidance for them does not
  belong in this repo. Update via `ng update`, one major version at a time.
  Pre-release docs live at [next.angular.dev](https://next.angular.dev/).
- **Rust**: the latest toolchain supports all historical editions; Edition 2024
  shipped with Rust 1.85.0 (RFC 3501). Cargo resolver `"3"` is the
  edition-2024 default (Rust 1.84+).
- **FastAPI**: the floor is Python `>= 3.10`, but CPython 3.10 is itself at/past
  EOL per [docs.python.org/3/](https://docs.python.org/3/). New services should
  target a supported CPython release; see
  `language-specific/python/PATTERNS.md`.

---

## Licences

All upstream material is **paraphrased and linked, never reproduced**. Long
verbatim excerpts would create an attribution obligation this repo does not carry.
Short idiomatic code snippets are fine.

| Source | Code licence | Documentation licence |
|---|---|---|
| Angular | MIT-style | **CC BY 4.0** — [angular.dev/license](https://angular.dev/license) |
| Ionic Framework | MIT | **Apache 2.0** (from `ionic-team/ionic-docs`) — stated on the docs home page |
| Capacitor | MIT | MIT |
| NestJS | MIT (`"license":"MIT"` in the registry manifest) | MIT |
| FastAPI | MIT | MIT |
| Rust | Dual MIT / Apache-2.0 | Books under CC-BY; see [doc.rust-lang.org](https://doc.rust-lang.org/) |

---

## Pages consulted

### Angular — `angular.dev`

Guide consumed by `language-specific/angular/`.

Core: [`/guide/signals`](https://angular.dev/guide/signals) ·
[`/guide/components`](https://angular.dev/guide/components) ·
[`/guide/components/inputs`](https://angular.dev/guide/components/inputs) ·
[`/outputs`](https://angular.dev/guide/components/outputs) ·
[`/lifecycle`](https://angular.dev/guide/components/lifecycle) ·
[`/queries`](https://angular.dev/guide/components/queries) ·
[`/advanced-configuration`](https://angular.dev/guide/components/advanced-configuration) ·
[`/guide/templates/control-flow`](https://angular.dev/guide/templates/control-flow) ·
[`/guide/templates/defer`](https://angular.dev/guide/templates/defer)

DI, HTTP, routing: [`/guide/di`](https://angular.dev/guide/di) ·
[`/guide/di/dependency-injection-context`](https://angular.dev/guide/di/dependency-injection-context) ·
[`/guide/di/creating-and-using-services`](https://angular.dev/guide/di/creating-and-using-services) ·
[`/guide/http`](https://angular.dev/guide/http) ·
[`/guide/http/making-requests`](https://angular.dev/guide/http/making-requests) ·
[`/guide/http/interceptors`](https://angular.dev/guide/http/interceptors) ·
[`/guide/routing`](https://angular.dev/guide/routing) ·
[`/guide/routing/define-routes`](https://angular.dev/guide/routing/define-routes) ·
[`/guide/routing/loading-strategies`](https://angular.dev/guide/routing/loading-strategies)

Rendering & performance: [`/guide/ssr`](https://angular.dev/guide/ssr) ·
[`/guide/hydration`](https://angular.dev/guide/hydration) ·
[`/guide/zoneless`](https://angular.dev/guide/zoneless) ·
[`/guide/performance`](https://angular.dev/guide/performance) ·
[`/best-practices/skipping-subtrees`](https://angular.dev/best-practices/skipping-subtrees)

Forms: [`/guide/forms`](https://angular.dev/guide/forms) ·
[`/guide/forms/reactive-forms`](https://angular.dev/guide/forms/reactive-forms) ·
[`/guide/forms/signals/overview`](https://angular.dev/guide/forms/signals/overview)

Testing: [`/guide/testing`](https://angular.dev/guide/testing) ·
[`/guide/testing/components-basics`](https://angular.dev/guide/testing/components-basics) ·
[`/components-scenarios`](https://angular.dev/guide/testing/components-scenarios) ·
[`/services`](https://angular.dev/guide/testing/services) ·
[`/using-component-harnesses`](https://angular.dev/guide/testing/using-component-harnesses) ·
[`/migrating-to-vitest`](https://angular.dev/guide/testing/migrating-to-vitest)

Reference & conventions: [`/style-guide`](https://angular.dev/style-guide) ·
[`/reference/versions`](https://angular.dev/reference/versions) ·
[`/reference/releases`](https://angular.dev/reference/releases) ·
[`/license`](https://angular.dev/license)

**Not used — these paths do not exist** (do not reintroduce them):
`/guide/injectors`, `/guide/components/standalone`, `/guide/performance/zoneless`.
The real equivalents are `/guide/di`, `/guide/components`, and `/guide/zoneless`.

### Ionic — `ionicframework.com/docs`

Guide consumed by `language-specific/ionic/`.

[`/docs`](https://ionicframework.com/docs) ·
[`/docs/intro/cli`](https://ionicframework.com/docs/intro/cli) ·
[`/docs/angular/overview`](https://ionicframework.com/docs/angular/overview) ·
[`/docs/angular/lifecycle`](https://ionicframework.com/docs/angular/lifecycle) ·
[`/docs/angular/navigation`](https://ionicframework.com/docs/angular/navigation) ·
[`/docs/angular/build-options`](https://ionicframework.com/docs/angular/build-options) ·
[`/docs/angular/testing`](https://ionicframework.com/docs/angular/testing) ·
[`/docs/angular/storage`](https://ionicframework.com/docs/angular/storage) ·
[`/docs/angular/performance`](https://ionicframework.com/docs/angular/performance) ·
[`/docs/components`](https://ionicframework.com/docs/components) ·
[`/docs/theming/basics`](https://ionicframework.com/docs/theming/basics) ·
[`/docs/theming/platform-styles`](https://ionicframework.com/docs/theming/platform-styles) ·
[`/docs/native`](https://ionicframework.com/docs/native) ·
[`/docs/utilities/gestures`](https://ionicframework.com/docs/utilities/gestures) ·
[`/docs/utilities/animations`](https://ionicframework.com/docs/utilities/animations) ·
[`/docs/techniques/security`](https://ionicframework.com/docs/techniques/security)

### Capacitor — `capacitorjs.com/docs`

[`/docs`](https://capacitorjs.com/docs) ·
[`/docs/getting-started`](https://capacitorjs.com/docs/getting-started) ·
[`/docs/getting-started/environment-setup`](https://capacitorjs.com/docs/getting-started/environment-setup) ·
[`/docs/basics/workflow`](https://capacitorjs.com/docs/basics/workflow) ·
[`/docs/apis/preferences`](https://capacitorjs.com/docs/apis/preferences)

Related: [Ionic Secure Storage](https://ionic.io/docs/secure-storage) (commercial)
and the [Capacitor Community plugin catalogue](https://github.com/capacitor-community/)
— see `language-specific/ionic/NATIVE.md` for why no first-party encrypted
keychain plugin exists in the OSS docs.

### NestJS — `docs.nestjs.com`

Consumed by `language-specific/javascript/` (NestJS lives in the JS/TS guide, not
its own directory).

**Provenance note — read this before trusting the list below.** Only
[`/`](https://docs.nestjs.com/) and [`/first-steps`](https://docs.nestjs.com/first-steps)
were actually read during the 2026-10-15 pass, and the hard version/runtime facts
came from the npm registry manifest (see below), which *was* read in full. The
remaining pages are the canonical upstream reading set for the NestJS material
that already existed in `language-specific/javascript/`; each was **verified to
resolve (HTTP 200) on 2026-10-15** but its content was **not** individually
re-distilled in that pass. Treat them as signposts for a human or a future
refresh, not as citations for a specific claim. If you need to assert something
about NestJS behaviour, fetch the relevant page first.

[`/`](https://docs.nestjs.com/) ·
[`/first-steps`](https://docs.nestjs.com/first-steps) ·
[`/modules`](https://docs.nestjs.com/modules) ·
[`/controllers`](https://docs.nestjs.com/controllers) ·
[`/providers`](https://docs.nestjs.com/providers) ·
[`/fundamentals/custom-providers`](https://docs.nestjs.com/fundamentals/custom-providers) ·
[`/fundamentals/testing`](https://docs.nestjs.com/fundamentals/testing) ·
[`/exception-filters`](https://docs.nestjs.com/exception-filters) ·
[`/pipes`](https://docs.nestjs.com/pipes) ·
[`/guards`](https://docs.nestjs.com/guards) ·
[`/interceptors`](https://docs.nestjs.com/interceptors) ·
[`/security/helmet`](https://docs.nestjs.com/security/helmet) ·
[`/techniques/validation`](https://docs.nestjs.com/techniques/validation) ·
[`/techniques/database`](https://docs.nestjs.com/techniques/database) ·
[`/techniques/configuration`](https://docs.nestjs.com/techniques/configuration) ·
[`/recipes/terminus`](https://docs.nestjs.com/recipes/terminus)

Version/runtime facts come from the npm registry manifest, read in full:
[`registry.npmjs.org/@nestjs/core/latest`](https://registry.npmjs.org/@nestjs/core/latest)
→ `12.1.3`, `engines.node: ">= 20"`, `type: "module"`, `license: "MIT"`,
peer deps `rxjs ^7.1.0` / `reflect-metadata ^0.1.12 || ^0.2.0`.

### FastAPI — `fastapi.tiangolo.com`

Guide consumed by `language-specific/python/`.

Tutorial: [`/tutorial/`](https://fastapi.tiangolo.com/tutorial/) ·
[`/tutorial/first-steps/`](https://fastapi.tiangolo.com/tutorial/first-steps/) ·
[`/tutorial/bigger-applications/`](https://fastapi.tiangolo.com/tutorial/bigger-applications/) ·
[`/tutorial/dependencies/`](https://fastapi.tiangolo.com/tutorial/dependencies/) ·
[`/tutorial/dependencies/dependencies-with-yield/`](https://fastapi.tiangolo.com/tutorial/dependencies/dependencies-with-yield/) ·
[`/tutorial/security/`](https://fastapi.tiangolo.com/tutorial/security/) ·
[`/tutorial/security/first-steps/`](https://fastapi.tiangolo.com/tutorial/security/first-steps/) ·
[`/tutorial/security/oauth2-jwt/`](https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/) ·
[`/tutorial/sql-databases/`](https://fastapi.tiangolo.com/tutorial/sql-databases/) ·
[`/tutorial/response-model/`](https://fastapi.tiangolo.com/tutorial/response-model/) ·
[`/tutorial/extra-models/`](https://fastapi.tiangolo.com/tutorial/extra-models/) ·
[`/tutorial/handling-errors/`](https://fastapi.tiangolo.com/tutorial/handling-errors/) ·
[`/tutorial/middleware/`](https://fastapi.tiangolo.com/tutorial/middleware/) ·
[`/tutorial/cors/`](https://fastapi.tiangolo.com/tutorial/cors/) ·
[`/tutorial/testing/`](https://fastapi.tiangolo.com/tutorial/testing/)

Advanced & async: [`/advanced/settings/`](https://fastapi.tiangolo.com/advanced/settings/) ·
[`/advanced/async-tests/`](https://fastapi.tiangolo.com/advanced/async-tests/) ·
[`/advanced/middleware/`](https://fastapi.tiangolo.com/advanced/middleware/) ·
[`/advanced/testing-dependencies/`](https://fastapi.tiangolo.com/advanced/testing-dependencies/) ·
[`/advanced/events/`](https://fastapi.tiangolo.com/advanced/events/) ·
[`/advanced/opentelemetry/`](https://fastapi.tiangolo.com/advanced/opentelemetry/) ·
[`/async/`](https://fastapi.tiangolo.com/async/) ·
[`/how-to/testing-database/`](https://fastapi.tiangolo.com/how-to/testing-database/)

### Python toolchain

[`docs.pydantic.dev/latest/`](https://docs.pydantic.dev/latest/) (+ `/concepts/fields/`, `/concepts/models/`, `/api/alias_generators/`) —
note these now **redirect** to `pydantic.dev/docs/validation/latest/...`.
[`docs.astral.sh/uv/`](https://docs.astral.sh/uv/) (+ `/uv/concepts/projects/dependencies/`) ·
[`docs.astral.sh/ruff/`](https://docs.astral.sh/ruff/) (+ `/ruff/configuration/`, `/ruff/settings/`) ·
[`docs.pytest.org/en/stable/`](https://docs.pytest.org/en/stable/) ·
[`mypy.readthedocs.io/en/stable/`](https://mypy.readthedocs.io/en/stable/) ·
[`docs.python.org/3/`](https://docs.python.org/3/) (+ `/3/library/contextvars.html`, `/3/library/logging.html`) ·
[`www.python-httpx.org/`](https://www.python-httpx.org/) (+ `/advanced/transports/`) ·
[`starlette.dev/testclient/`](https://starlette.dev/testclient/) ·
[`bandit.readthedocs.io/en/latest/`](https://bandit.readthedocs.io/en/latest/) (PyCQA SAST, Apache-2.0, v1.9.4 line) ·
[`mutmut.readthedocs.io/en/latest/`](https://mutmut.readthedocs.io/en/latest/) (Python mutation tester; POSIX/fork-only, mutmut 3+ mutates only inside functions)

Ecosystem (linked from fetched pages, not fetched directly):
[`alembic.sqlalchemy.org/en/latest/`](https://alembic.sqlalchemy.org/en/latest/) ·
[`sqlmodel.tiangolo.com/tutorial/fastapi/tests/`](https://sqlmodel.tiangolo.com/tutorial/fastapi/tests/) ·
[`github.com/fastapi/full-stack-fastapi-template`](https://github.com/fastapi/full-stack-fastapi-template) ·
[`github.com/florimondmanca/asgi-lifespan`](https://github.com/florimondmanca/asgi-lifespan)

### Rust — `doc.rust-lang.org`

Guide consumed by `language-specific/rust/`. The Bookshelf hub is
[`doc.rust-lang.org/`](https://doc.rust-lang.org/).

The Book: [`ch09 Error Handling`](https://doc.rust-lang.org/stable/book/ch09-00-error-handling.html) ·
[`ch09-03 To panic! or Not`](https://doc.rust-lang.org/stable/book/ch09-03-to-panic-or-not-to-panic.html) ·
[`ch11 Testing`](https://doc.rust-lang.org/stable/book/ch11-00-testing.html) ·
[`ch11-01 Writing Tests`](https://doc.rust-lang.org/stable/book/ch11-01-writing-tests.html) ·
[`ch11-03 Test Organization`](https://doc.rust-lang.org/stable/book/ch11-03-test-organization.html) ·
[`ch14-01 Release Profiles`](https://doc.rust-lang.org/stable/book/ch14-01-release-profiles.html) ·
[`ch14-03 Workspaces`](https://doc.rust-lang.org/stable/book/ch14-03-cargo-workspaces.html) ·
[`ch17 Async/Await`](https://doc.rust-lang.org/stable/book/ch17-00-async-await.html)

Tooling & language reference: [`Style Guide`](https://doc.rust-lang.org/stable/style-guide/index.html) ·
[`Clippy Book`](https://doc.rust-lang.org/stable/clippy/index.html) ·
[`Cargo Book`](https://doc.rust-lang.org/stable/cargo/index.html) ·
[`Cargo resolver reference`](https://doc.rust-lang.org/cargo/reference/resolver.html) ·
[`rustdoc documentation tests`](https://doc.rust-lang.org/stable/rustdoc/write-documentation/documentation-tests.html) ·
[`Edition Guide`](https://doc.rust-lang.org/stable/edition-guide/index.html) ·
[`Rust 2024 edition`](https://doc.rust-lang.org/edition-guide/rust-2024/index.html) ·
[`The Reference`](https://doc.rust-lang.org/stable/reference/index.html) ·
[`std API docs`](https://doc.rust-lang.org/stable/std/index.html) ·
[`Rustonomicon`](https://doc.rust-lang.org/stable/nomicon/index.html) ·
[`API Guidelines`](https://rust-lang.github.io/api-guidelines/) ·
[`Clippy lint list — `cognitive_complexity``](https://rust-lang.github.io/rust-clippy/master/index.html#cognitive_complexity)

**Not used — does not exist:** `/stable/edition-guide/editions-2024/index.html`
(404). The correct path is `/edition-guide/rust-2024/`.

Rust ecosystem (third-party, **not** official Bookshelf — labelled as such in the
guide): [`tokio.rs`](https://tokio.rs/) ·
[`docs.rs/tokio — `#[tokio::test]``](https://docs.rs/tokio/latest/tokio/attr.test.html) ·
[`docs.rs/axum`](https://docs.rs/axum/latest/axum/) ·
[`serde.rs`](https://serde.rs/) ·
[`docs.rs/thiserror`](https://docs.rs/thiserror/latest/thiserror/) ·
[`docs.rs/anyhow`](https://docs.rs/anyhow/latest/anyhow/) ·
[`rustsec.org`](https://rustsec.org/) (source of `cargo-audit`, confirming it is
third-party rather than built in) ·
[`embarkstudios.github.io/cargo-deny/`](https://embarkstudios.github.io/cargo-deny/)
(dependency-graph linting for licence/ban/advisory/sources policy; ships
`EmbarkStudios/cargo-deny-action@v1`)

Rust formatting/toolchain facts verified against `rust-lang` upstream:
[`rustfmt` style editions](https://doc.rust-lang.org/edition-guide/rust-2024/rustfmt-style-edition.html)
(`style_edition = "2024"`) and
[`rust-lang/rustfmt` CI guidance](https://github.com/rust-lang/rustfmt)
(`cargo build --locked`, `cargo test --locked`, `cargo fmt --all -- --check`).

---

## Findings that constrain our guides

Recorded here because they are the reason a guide says what it says.

> **Status note.** The three gate-coverage findings below — that
> `check-code-principles.sh` did not analyse Python or Rust, that
> `detect-saga-outbox.sh` did not scan them, and that the silent clean exit hid
> both — were **addressed by ADR 0006**
> ([`docs/adr/0006-python-rust-gate-coverage.md`](./adr/0006-python-rust-gate-coverage.md))
> on branch `feat/python-rust-gate-coverage`. They are kept verbatim as the
> record of what was found and why the ADR was necessary. Read them as
> historical: both scripts now scan `.py` and `.rs`, in a warn-only phase per
> ADR 0006 D6, and the zero-file message now enumerates the extensions it
> scanned. The ordering constraint they document — detection and the four
> downstream gates must change together — still applies to any future language.

- **Angular's default test runner is Vitest**, not Jest and not Karma — the CLI
  default builder is `@angular/build:unit-test` (jsdom). Karma is legacy with an
  experimental migration path. Source: [`/guide/testing`](https://angular.dev/guide/testing)
  and [`/guide/testing/migrating-to-vitest`](https://angular.dev/guide/testing/migrating-to-vitest).
- **Zoneless change detection is the default from Angular v21+**, and OnPush is
  the default from v22. Sources: [`/guide/zoneless`](https://angular.dev/guide/zoneless),
  [`/best-practices/skipping-subtrees`](https://angular.dev/best-practices/skipping-subtrees).
- **Ionic's official Angular testing page exists** but is stale relative to
  Angular v22 in two specific ways: its E2E section still describes the older
  Protractor-based generated scaffold, and its unit-test examples use Jasmine
  spies with the NgModule-era `HttpClientTestingModule`. Our guide therefore
  treats that page as a source of *Ionic-specific* detail only
  (`componentOnReady`, page-lifecycle testing, `provideIonicAngular()` in
  TestBed) and takes the runner and HTTP-testing APIs from Angular's docs.
  Where the two disagree, `language-specific/angular/TESTING.md` wins.
  Sources: [`/docs/angular/testing`](https://ionicframework.com/docs/angular/testing),
  [`angular.dev/guide/testing`](https://angular.dev/guide/testing).
- **Ionic OSS ships no first-party encrypted keychain/keystore plugin.**
  Capacitor Preferences is explicitly unencrypted (UserDefaults /
  SharedPreferences). Our "secrets only in encrypted OS key storage, wrapped in a
  service" rule is therefore *house policy*, not an Ionic recommendation, and is
  labelled as such.
- **FastAPI's tutorial uses SQLModel** (SQLAlchemy + Pydantic, same author) and
  states plainly that FastAPI forces no ORM. Source:
  [`/tutorial/sql-databases/`](https://fastapi.tiangolo.com/tutorial/sql-databases/).
- **FastAPI's default test client is Starlette's `TestClient`**;
  `httpx.AsyncClient` + `ASGITransport` is for genuinely async tests and skips
  lifespan events. Sources:
  [`/tutorial/testing/`](https://fastapi.tiangolo.com/tutorial/testing/),
  [`/advanced/async-tests/`](https://fastapi.tiangolo.com/advanced/async-tests/).
- **No official Rust cyclomatic-complexity gate exists — and neither does an
  in-repo one.** Clippy ships `clippy::cognitive_complexity`, but it is in the
  `restriction` group, **allow-by-default**, threshold 25, and the Clippy team's
  own docs now express doubt about the metric. Separately,
  `scripts/check-code-principles.sh` enumerates only `*.java`, `*.go` and
  `*.ts`/`*.tsx`/`*.js`/`*.jsx` (lines 307–309) and exits *clean* with "No
  Java, Go, or JS/TS source files found" when none match (line 311) — so it
  **does not analyse Rust or Python at all**. Rust complexity is therefore
  review-enforced for now, with `-W clippy::cognitive_complexity` at a tightened
  threshold as the interim mechanical signal; Python is covered by ruff `C901`
  configured per-project, which *is* real enforcement. Neither is equivalent to
  PMD (`language-specific/java/`) or golangci `cyclop`/`gocognit`
  (`language-specific/go/`). Extending the script to `*.rs`/`*.py` is a
  gate-catalog change requiring an ADR.
- **`scripts/detect-saga-outbox.sh` does not scan Python or Rust.** Its
  `CODE_FILES` filter is `\.(java|go|ts|js|sql|xml)$` (line 79) and its
  migration-name check allows only `*.java|*.go|*.ts|*.js|*.sql|*.xml`
  (line 69). A FastAPI or Rust service containing saga/outbox code therefore
  leaves `SAGA_DETECTED`/`OUTBOX_DETECTED` false, and every downstream gate
  silently skips. This is a coverage hole, not a passing gate.
- **Extending that detection alone would break Python/Rust repos.** All four
  downstream gates are hardcoded to Java/Go/Node: `check-saga-timeouts.sh`
  matches `WithTimeout`/`.go`, `check-saga-tests.sh` matches `.go|.ts|.java`,
  and `lint-outbox-schema.sh` plus `check-outbox-relay.sh` match
  `.java|.go|.js|.ts`. Setting `SAGA_DETECTED=true` for a Python service would
  run gates looking for patterns Python cannot express, producing false
  failures. **Detection and the four gates must be extended together**, under an
  ADR — not piecemeal.
- **`ci/gitlab/frontend/ci-angular.yml` already existed** and is deliberately
  runner-agnostic (`.angular-unit` runs `npm run test:ci --if-present || npm
  test`), so it needs no change for Angular's Vitest default — the child repo
  wires `test:ci`. There is no `child-ci-angular.yml`, and no Python, Rust or
  Ionic CI template of any kind.
- **`scripts/check-code-principles.sh` exits clean when it scans nothing.**
  Lines 307–309 enumerate only `*.java`, `*.go` and `*.ts`/`*.tsx`/`*.js`/`*.jsx`;
  line 311 then calls `finish_clean` with "No Java, Go, or JS/TS source files
  found — nothing to check". A Python-only or Rust-only repo therefore passes
  the design-principles gate without being analysed. Note `finish_clean` is a
  *shared* helper (`scripts/check-common.sh`) used by several gates and covered
  by `scripts/tests/check-common.bats`, so the fix belongs in the caller, not
  the helper.
- **`cargo-audit` and `cargo-mutants` are third-party subcommands**, not built
  into Cargo. `cargo-mutants` could not be verified against a canonical source
  and is flagged evaluate-first in `language-specific/rust/TESTING.md`.

---

## Refreshing these guides

Upstream moves; these pins go stale. When refreshing:

1. Re-check the **Version pins** table against the upstream authority column and
   update it first.
2. Re-fetch the pages listed for the affected stack and correct the guide.
3. Record the new retrieval date at the top of this file.
4. Remove URLs that no longer resolve, and add new ones — never leave a citation
   here that nobody has fetched.

Angular's 24-month support window and Rust's 6-week release cadence are the two
fastest-moving; check those most often.
