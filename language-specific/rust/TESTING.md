# Rust — Testing

The layered test strategy (unit / acceptance / integration / E2E), what each
layer proves, run cadence, and the "tests that encode a defect" procedure are
defined in [`docs/TESTING.md`](../../docs/TESTING.md) and inherited here —
this file covers the Rust mechanisms for each layer.

Labels: **[official]** = Rust Book / rustdoc book, **[convention]** = repo
rule, **[ecosystem]** = third-party crate.

## Layer → Rust Mechanism

| Layer (docs/TESTING.md) | Rust mechanism | Where |
|---|---|---|
| Unit | `#[test]` fns in a `#[cfg(test)] mod tests` colocated in the source file | `src/**/*.rs` |
| Doc-tests (**Rust-specific extra layer**) | `///` examples on `pub` items — compiled and run by `cargo test` | `src/**/*.rs` |
| Acceptance | Same as unit/integration, named to the spec scenario ID | `src/` or `tests/` |
| Integration | One file per scenario group in `tests/`; each file is a separate crate using only the public API | `tests/*.rs` |
| E2E | Full Dockerized service + HTTP client (repo-standard E2E layer) | per docs/TESTING.md §E2E |

`cargo test` runs unit tests, integration tests, and doc-tests in one command.
**[official]** <https://doc.rust-lang.org/stable/book/ch11-00-testing.html>

## Unit Tests (Book ch11 conventions)

All of the following are official conventions from
<https://doc.rust-lang.org/stable/book/ch11-01-writing-tests.html> and
<https://doc.rust-lang.org/stable/book/ch11-03-test-organization.html>:

- `#[test]` marks a test function; the test harness is built into `cargo test`.
- Unit tests live in a `mod tests` annotated `#[cfg(test)]` **in the same file
  as the code under test**, with `use super::*;` — `#[cfg(test)]` keeps test
  code out of normal builds.
- Unit tests may test private items.
- Each test runs in its own thread; a test fails when it panics.
- Assertions: `assert!(cond)`, `assert_eq!(a, b)`, `assert_ne!(a, b)`.
  `assert_eq!`/`assert_ne!` print both values on failure and require
  `PartialEq + Debug` (derive them). Argument order (`left`/`right`) does not
  affect the failure message.
- Custom failure messages: extra args are passed to `format!` —
  `assert!(r.contains("Carol"), "greeting did not contain name, value was `{r}`")`.
- `#[should_panic]`, optionally `#[should_panic(expected = "substring")]`,
  tests that a condition panics.
- Tests may return `Result<(), E>` so `?` works in the body. Such tests
  **cannot** use `#[should_panic]` — assert `value.is_err()` instead.
- `#[ignore]` skips a test; `cargo test <name>` filters by name.

```rust
// src/services/user.rs  [convention: one tests module per source file]
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn create_user_rejects_taken_email() {
        let svc = UserService::new(FakeUserRepository::default());
        let err = svc.create_user(cmd()).unwrap_err(); // unwrap OK in tests
        assert!(matches!(err, ServiceError::EmailTaken));
    }

    #[test]
    fn result_style_test() -> Result<(), ServiceError> {
        let user = UserService::new(FakeUserRepository::default()).create_user(cmd())?;
        assert_eq!(user.email, "a@b.c");
        Ok(())
    }
}
```

Name tests after scenario + expected outcome (`create_user_rejects_taken_email`),
mirroring docs/TESTING.md §Unit Tests.

## Doc-Tests (call this out — it is a Rust strength)

**[official]** rustdoc executes documentation examples as tests: "rustdoc
supports executing your documentation examples as tests. This makes sure that
examples within your documentation are up to date and working" —
<https://doc.rust-lang.org/stable/rustdoc/write-documentation/documentation-tests.html>.
Documentation literally cannot rot: a stale example fails `cargo test`.

Mechanics from the same page:

- A doc-test passes if it compiles and runs without panicking; `assert!` works
  inside examples.
- Lines starting with `#` are hidden from rendered docs but compiled — use for
  setup boilerplate.
- Fence attributes: `ignore`, `no_run` (compile only), `should_panic`,
  `compile_fail`, `edition2024`, `standalone_crate`, `test_harness`,
  `ignore-<target>`.
- `?` in examples needs a hidden `fn main() -> Result<…>` or a trailing
  `# Ok::<(), io::Error>(())`.
- README testing: `#[doc = include_str!("../README.md")] #[cfg(doctest)] pub
  struct ReadmeDoctests;` in `lib.rs`.
- In Edition 2024 compatible doc-tests are merged into one compilation for
  speed.

**[convention]** Every `pub` item gets a `///` doc comment; public API items
get at least one runnable example.

## Integration Tests

**[official]** (Book ch11-03, link above):

- `tests/` at the package root, next to `src/`. Each file is compiled as its
  own crate and can only use the library's **public API** — no `#[cfg(test)]`
  needed.
- Shared helpers go in `tests/common/mod.rs` (a plain `tests/common.rs` would
  be compiled as an extra zero-test target) and are pulled in with
  `mod common;`.
- `cargo test --test <file>` runs one integration test file.
- Binary-only crates cannot be integration-tested — keep logic in `src/lib.rs`
  and `src/main.rs` thin (this is why SKILL.md mandates that layout).

**[convention]** Integration tests cross one boundary (HTTP handler → service →
fake repo; service → real SQLite). Per docs/TESTING.md §Integration Tests,
prefer in-memory alternatives: SQLite `:memory:` for SQL stores, an in-process
HTTP stub for upstream services. With axum, run the real `Router` against a
tokio `TcpListener` on an ephemeral port, or use tower's test helpers — the
axum docs note tower "isn't strictly necessary either but helpful for testing"
(<https://docs.rs/axum/latest/axum/>). **[ecosystem]**

## Testing Async Code

**[official]** The language ships async/await but no runtime (Book ch17:
<https://doc.rust-lang.org/stable/book/ch17-00-async-await.html> — runtimes are
"third-party crates"), so async tests need a runtime-provided test attribute.

**[ecosystem]** With the repo-standard Tokio runtime, use `#[tokio::test]`:
"Marks async function to be executed by runtime, suitable to test environment"
— <https://docs.rs/tokio/latest/tokio/attr.test.html>. Requires tokio's
`macros` + `rt` features (dev-dependency is fine). Details from the same page:

- Default is a **current-thread** runtime, one per test.
- `#[tokio::test(flavor = "multi_thread", worker_threads = 2)]` for
  concurrency-sensitive tests (needs `rt-multi-thread`).
- `#[tokio::test(start_paused = true)]` auto-advances virtual time — needs the
  `test-util` feature; use it for timeout/retry tests instead of real sleeps.

```rust
#[tokio::test]
async fn health_reports_all_dependencies() {
    let state = test_state(); // Arc<AppState> wired with fakes
    let resp = api::health(state).await;
    assert_eq!(resp.status, StatusCode::OK);
}
```

## Mocking & Stubbing via Trait Impls

**[convention]** The DI traits (PATTERNS.md §Dependency Injection) are the
mock seams. Default is a **hand-written in-memory fake** — no mock framework —
consistent with docs/CODING_CONVENTIONS.md §Dependencies ("prefer stdlib,
justify each dependency") and the Go guide's stance on testify/gomock:

```rust
#[derive(Default)]
pub struct FakeUserRepository {
    users: std::sync::Mutex<HashMap<String, User>>,
}

#[async_trait::async_trait] // or native async-fn-in-trait, per repo choice
impl UserRepository for FakeUserRepository {
    async fn insert(&self, user: User) -> Result<User, RepoError> { /* ... */ }
}
```

- Mock at architectural boundaries (repositories, external clients), assert on
  return values, not call sequences — docs/TESTING.md §Test Behavior, Not
  Implementation.
- **[ecosystem]** `mockall` (<https://docs.rs/mockall>) is the optional
  upgrade when a trait surface is too large for hand-written fakes — same
  "justify it" bar as testify in Go. (It is common enough that Tokio itself
  uses it as a dev-dependency.)

## Test Data Builders

docs/TESTING.md §Test Data prefers the builder pattern. Rust shape
**[convention]**: `Default` + `with_*` methods returning `Self`:

```rust
pub struct TestUser { role: String, channel: String }

impl Default for TestUser {
    fn default() -> Self { Self { role: "USER".into(), channel: "WEB".into() } }
}

impl TestUser {
    pub fn with_role(mut self, role: &str) -> Self { self.role = role.into(); self }
    pub fn build(self) -> User { /* ... */ }
}
// usage: TestUser::default().with_role("ADMIN").build()
```

## Property & Mutation Testing (`production` tier)

Both are `production`-tier per [`docs/CONFORMANCE_TIERS.md`](../../docs/CONFORMANCE_TIERS.md)
and docs/TESTING.md — not required at `mvp`.

- **Property testing [ecosystem]:** docs/TESTING.md names tools for Java/Go/JS
  but not Rust; this guide nominates **`proptest`**
  (<https://docs.rs/proptest>) as the Rust convention (it is used as a
  dev-dependency by Tokio itself; `quickcheck` is also accepted).
  `scripts/check-code-principles.sh` now detects `proptest`/`quickcheck` in
  source or `Cargo.toml` and warns when neither is present (ADR 0006 D1,
  warn-only during that ADR's D6 phase). Use for invariants — "result is never
  negative", "operation is idempotent" — not arbitrary properties.
- **Mutation testing [ecosystem]:** docs/TESTING.md names PiTest/Gremlins/
  Stryker for the other languages. The Rust candidate is **`cargo-mutants`**
  (community cargo subcommand; not verified against official Rust docs here —
  evaluate, then adopt via the usual gate/ADR process before wiring into CI).
  Same cadence rule: periodic runs and pre-release, not every commit.

## Coverage

**[convention]** Advisory, PR-only signal — never a blocking gate
(docs/TESTING.md §Code Coverage). Rust has no built-in coverage; the common
community route is LLVM-based instrumentation (e.g. `cargo-llvm-cov`; evaluate
before adopting). Treat "coverage should not decrease from baseline" as a
review guideline.

## Layer Boundaries

- Unit tests touch no network, filesystem, or external service — dependencies
  are trait fakes.
- Integration tests cross exactly one architectural boundary (HTTP → handler →
  service, or service → real in-memory DB).
- E2E tests run the real compiled binary in Docker against real dependencies
  (docs/TESTING.md §E2E — one script shared by CI and local dev, readiness
  polling instead of fixed sleeps, exit-status-preserving cleanup).
