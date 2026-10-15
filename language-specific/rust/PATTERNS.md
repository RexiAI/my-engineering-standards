# Rust — Patterns

Deep patterns for the Rust stack. The layered architecture, error philosophy,
logging, and security rules come from the root `AGENTS.md` and `docs/` — this
file is the Rust expression of them, not a replacement.

Claims are labeled: **[official]** (rust-lang.org docs), **[convention]** (this
repo's team rule), **[ecosystem]** (third-party crate, cited to its own docs).

## Error Handling

**[official]** The Book splits errors into *recoverable* (`Result<T, E>`) and
*unrecoverable* (`panic!` — always a symptom of a bug):
<https://doc.rust-lang.org/stable/book/ch09-00-error-handling.html>. Rust has
no exceptions; `Result` is the default for anything that might fail, and
returning `Result` leaves the recovery decision to the caller
(<https://doc.rust-lang.org/stable/book/ch09-03-to-panic-or-not-to-panic.html>).

This maps 1:1 onto docs/CODING_CONVENTIONS.md §Error Handling Philosophy:
expected failures (validation, not-found, conflict) are values in a typed
error enum; `panic!` is reserved for broken invariants.

**[ecosystem]** The typed error enum is derived with `thiserror` (a derive
macro for `std::error::Error` that "deliberately does not appear in your
public API" — <https://docs.rs/thiserror/latest/thiserror/>). Applications
propagate with `anyhow`, a trait-object error type "for easy idiomatic error
handling in Rust applications", adding context with `.context()` /
`.with_context()` — <https://docs.rs/anyhow/latest/anyhow/>. The
*thiserror-in-libraries / anyhow-in-applications* split is an ecosystem
convention derived from how those crates document themselves, not an official
Rust rule. **[convention]**

```rust
// src/error.rs — library/service layer: typed enum, thiserror-derived
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ServiceError {
    #[error("user not found: {0}")]
    NotFound(String),
    #[error("email already taken")]
    EmailTaken,
    #[error("storage failure")]
    Storage(#[from] sqlx::Error), // infrastructure = wrap with #[from]
}

// Service returns the typed error; expected failures are values
pub async fn create_user(&self, cmd: CreateUser) -> Result<User, ServiceError> {
    if self.users.exists_by_email(&cmd.email).await? {
        return Err(ServiceError::EmailTaken);
    }
    Ok(self.users.insert(cmd.into()).await?)
}
```

```rust
// src/main.rs — application edge: anyhow + context
fn main() -> anyhow::Result<()> {
    let cfg = load_config().context("loading configuration")?;
    // ...
}
```

**Boundary translation [convention]:** the `api/` layer converts `ServiceError`
into HTTP responses in one place (an axum `IntoResponse` impl or a match in the
handler), mirroring the Go `ErrorMiddleware` pattern. Controllers never leak
internal error strings — upstream/third-party error bodies never reach the
client (docs/SECURITY.md §Upstream Error Responses Must Not Reach the Client).

```rust
impl IntoResponse for ServiceError {
    fn into_response(self) -> Response {
        let (status, code) = match &self {
            ServiceError::NotFound(_) => (StatusCode::NOT_FOUND, "NOT_FOUND"),
            ServiceError::EmailTaken => (StatusCode::CONFLICT, "EMAIL_TAKEN"),
            ServiceError::Storage(_) => (StatusCode::INTERNAL_SERVER_ERROR, "INTERNAL"),
        };
        // log the full error server-side; return only the static code
        tracing::error!(error = %self, "request failed");
        (status, Json(json!({ "error": code }))).into_response()
    }
}
```

## unwrap / expect Discipline

**[official]** Per
<https://doc.rust-lang.org/stable/book/ch09-03-to-panic-or-not-to-panic.html>:
`unwrap`/`expect` are appropriate in examples, prototypes, and tests; `expect`
is acceptable in production only where other logic guarantees success and the
reason is documented in the `expect` message (the Book's example: parsing a
hardcoded IP literal). Panic is right when a contract/invariant is broken and
continuing could be insecure.

**[convention]** Production code paths use these instead:

| Instead of | Use |
|---|---|
| `x.unwrap()` | `x?` with a typed error, or `.ok_or(ServiceError::…)?` for `Option` |
| `x.expect("msg")` | `?`, `unwrap_or(default)`, `unwrap_or_else`, or `match` |
| Panic on bad input | Validate in a constructor (`Guess::new` pattern, Book ch09-03) so invalid states are unrepresentable |
| Array indexing `v[i]` | `v.get(i)` + explicit handling |

Enforce mechanically: `#![warn(clippy::unwrap_used, clippy::expect_used)]`
with `#[allow]` on `#[cfg(test)]` modules; both are `restriction`-group lints
(<https://doc.rust-lang.org/stable/clippy/index.html> — the Clippy Book lists
`clippy::unwrap_used` as an example restriction-lint use: "preventing panicking
in certain functions").

## Ownership & Borrowing Discipline

- **[convention]** APIs take borrowed input (`&str`, `&[T]`, `&Path`) and
  return owned values when the caller needs ownership — the "accept borrowed
  arguments" direction of the official API guidelines
  (<https://rust-lang.github.io/api-guidelines/>, authored by the Rust library team).
- **[convention]** Do not `.clone()` to silence the borrow checker. Fix the
  ownership structure (narrow scopes, pass references, split functions). A
  clone in a hot path is a review flag; a clone for clarity at a cold boundary
  is fine.
- **[convention]** `Cow<'_, str>` for functions that usually borrow but
  sometimes must produce an owned value.
- **[convention]** Shared ownership (`Rc`/`Arc`) is for genuinely shared
  state (e.g. injected dependencies), not a workaround for unclear ownership.

## Dependency Injection (Trait-Based)

The root AGENTS.md rule — "use dependency injection; avoid service locator or
static state" — is expressed in Rust as **traits at layer boundaries +
constructor injection**. **[convention]**

Two idioms:

```rust
// 1. Generics (static dispatch) — default for library crates and services
pub struct UserService<R: UserRepository> {
    users: R,
}

// 2. Arc<dyn Trait> (dynamic dispatch) — application wiring where the
//    concrete type varies (real DB in prod, fake in tests)
pub struct AppState {
    pub users: Arc<dyn UserRepository>,
}
```

Wiring lives in `main.rs` (or a dedicated `wiring` module when it outgrows a
screenful — same escalation rule as Go's `dependency_injection.go`). No DI
framework.

**Banned [convention, backed by AGENTS.md]:** global mutable `static`,
`lazy_static`/`once_cell` singletons used as hidden service locators, and
`thread_local` state standing in for injection. Edition 2024 additionally makes
taking a reference to `static mut` a hard error
(<https://doc.rust-lang.org/edition-guide/rust-2024/static-mut-references.html>)
— the language itself is pushing this direction. **[official]** A process-wide
immutable constant (`const`, or `OnceLock` for a compiled-once config value) is
acceptable; anything a test would need to swap out must be an injected
dependency, not a global.

Every injected trait gets an in-memory fake for tests — see TESTING.md.

## Module & Workspace Layout ↔ Layering

docs/ARCHITECTURE.md's stack maps onto modules (or crates, once split):

| Repo layer | Rust module | Depends on |
|---|---|---|
| Controller | `api/` (handlers, DTOs, error→HTTP, `/health`) | `services/` traits/types |
| Service | `services/` | `repositories/` **traits**, `domain/`, `clients/` traits |
| Repository | `repositories/` | driver crates, `domain/` |
| External | `clients/` (upstream services), DB drivers | — |

Rules **[convention]**:

- Layers may only depend on the layer directly below; `api/` never touches
  `repositories/` directly. Enforce with module privacy (`pub(crate)`) and
  review; a workspace split (crate per layer) makes the boundary
  compiler-enforced, the same trick Go's `internal/` provides.
- Services depend on repository *traits*, never concrete repositories — that
  trait is the test seam.
- `/health` handler aggregates a `health_check()` method on each dependency
  trait (root AGENTS.md: health endpoints check all external deps).
- Split into workspace crates only when compilation time or reuse demands it
  (YAGNI). The official workspaces chapter covers shared `Cargo.lock`/`target/`
  and `cargo test -p <crate>`:
  <https://doc.rust-lang.org/stable/book/ch14-03-cargo-workspaces.html>. **[official]**

## Async Runtime and Send/Sync

**[official]** The Rust language provides `async`/`await`, futures, and
streams; **runtimes are third-party crates** — Book ch17:
<https://doc.rust-lang.org/stable/book/ch17-00-async-await.html>.

**[ecosystem/convention]** This repo's default runtime is **Tokio** — "an
asynchronous runtime for the Rust programming language… multi-threaded,
work-stealing scheduler" (<https://tokio.rs/>) — and the default HTTP framework
is **axum**, "an HTTP routing and request-handling library that focuses on
ergonomics and modularity", explicitly "designed to work with tokio and hyper"
(<https://docs.rs/axum/latest/axum/>). Choosing a different runtime is an ADR
(docs/ARCHITECTURE.md §Architecture Decision Records).

Rules:

- **`Send` bounds [ecosystem]:** spawning onto Tokio's multi-threaded runtime
  requires `Send` futures (`tokio::spawn`,
  <https://docs.rs/tokio/latest/tokio/fn.spawn.html>). Do not hold
  `std::sync::MutexGuard`, `Rc`, or raw pointers across `.await` — use
  `tokio::sync` primitives for state shared across await points. If a future
  fails a `Send` bound, fix what's held across the await, don't pin the whole
  service to one thread by reflex.
- **Never block the runtime [ecosystem]:** blocking std calls (sync DB
  drivers, `std::fs`, heavy CPU work) go through `tokio::task::spawn_blocking`
  (<https://docs.rs/tokio/latest/tokio/task/fn.spawn_blocking.html>) or a
  dedicated thread.
- **Every external call gets a timeout** (docs/RESILIENCE.md is the tiered
  rule: a bare timeout is the `mvp` floor) — e.g. `tokio::time::timeout`
  (<https://docs.rs/tokio/latest/tokio/time/index.html>). **[ecosystem]**
- `async fn` in traits is stable on current toolchains; where a trait object
  (`Arc<dyn Trait>`) needs async methods, box the future or use the
  `trait_variant`/`async_trait`-style pattern of the chosen framework — decide
  once per repo and note it in the crate docs. **[convention]**

## Structured Logging & Tracing

docs/OBSERVABILITY.md + root AGENTS.md require structured logging with trace
IDs at service-method boundaries. **[convention]**

**[ecosystem]** Default facade: `tracing` — part of the Tokio stack:
"Unified insight into the application and libraries. Provides structured,
event-based, data collection and logging" (<https://tokio.rs/>). `log` +
`env_logger` is acceptable for small CLI tools; services use `tracing` with a
JSON subscriber in production.

```rust
#[tracing::instrument(skip_all, fields(user_id = %cmd.user_id))]
pub async fn create_user(&self, cmd: CreateUser) -> Result<User, ServiceError> {
    tracing::info!("creating user");
    // ...
}
```

- One span per service method (`#[tracing::instrument]`); request middleware
  extracts the W3C `traceparent` header and attaches the trace ID to the
  request span, then propagates it downstream (docs/OBSERVABILITY.md).
- Never log PII, secrets, or tokens (docs/CODING_CONVENTIONS.md §Logging).

## `unsafe` Policy

**[convention]** Default answer: don't. Requirements when unavoidable:

1. A written justification (why safe Rust cannot express this) reviewed in the
   PR — treat it like a mini-ADR in the PR description.
2. Every `unsafe` block carries a `// SAFETY:` comment stating the invariants
   that make it sound.
3. The reviewer has working knowledge of the Rustonomicon
   (<https://doc.rust-lang.org/stable/nomicon/index.html>). **[official resource]**
4. `unsafe` stays behind a safe public API; the smallest possible scope is
   marked.

Edition 2024 tightened the language around `unsafe` **[official]**:

- Unsafe operations inside an `unsafe fn` body now require an explicit
  `unsafe` block — `unsafe_op_in_unsafe_fn` warns by default
  (<https://doc.rust-lang.org/edition-guide/rust-2024/unsafe-op-in-unsafe-fn.html>).
- Unsafe attributes require the `#[unsafe(no_mangle)]` form
  (<https://doc.rust-lang.org/edition-guide/rust-2024/unsafe-attributes.html>).
- Some std functions became `unsafe` in Edition 2024
  (<https://doc.rust-lang.org/edition-guide/rust-2024/newly-unsafe-functions.html>).

## Edition 2024 Checklist (verified items)

All verified against official docs:

- `edition = "2024"` in `Cargo.toml`; the edition shipped with Rust 1.85.0,
  RFC 3501 (<https://doc.rust-lang.org/edition-guide/rust-2024/index.html>).
- Workspace `resolver = "3"` is the Edition 2024 default; requires Rust 1.84+
  (<https://doc.rust-lang.org/cargo/reference/resolver.html>).
- References to `static mut` are errors
  (<https://doc.rust-lang.org/edition-guide/rust-2024/static-mut-references.html>).
- `unsafe_op_in_unsafe_fn` warns by default; unsafe attributes need
  `#[unsafe(...)]` (links above).
- Doc-tests: compatible examples are merged into one compilation for speed;
  opt out per example with `standalone_crate`; per-example edition override via
  the `edition2024` fence attribute
  (<https://doc.rust-lang.org/stable/rustdoc/write-documentation/documentation-tests.html>).
- Migrate with `cargo fix --edition` (Edition Guide).

## Config & Secrets

**[convention]** (rules from docs/SECURITY.md):

- Parse all environment/config into **one typed `Config` struct at startup**
  (`serde`-derived deserialization; `serde` is the ecosystem-standard
  serialization framework — <https://serde.rs/>). Missing/invalid config fails
  fast at boot with a clear message, not at first use.
- `.env` files are fine for small projects and must be gitignored; `production`
  tier uses a secrets manager. Never commit credentials; never embed secrets in
  `Cargo.toml`, build scripts, or source.
