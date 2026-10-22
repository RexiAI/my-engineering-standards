---
name: rust
description: Rust standards: project shape (Cargo workspaces, Edition 2024, thin binary + library crate), toolchain commands (cargo build / test / fmt / clippy / doc / audit), lint and complexity-gate configuration, always-rules (Result-based typed errors, no unwrap in production paths, trait-based DI with no global static state, no unsafe without review), and pointers to PATTERNS.md / TESTING.md. Use whenever a child repo uses Rust — Cargo.toml, .rs files, cargo, rustfmt, clippy, tokio, axum, serde.
license: See repo root
applyTo: "**/Cargo.toml, **/*.rs"
---

# Rust Standards

Entry point for the Rust stack. Repo-wide rules (conventional commits, layered
testing, secrets handling, layered architecture) are inherited from the root
`AGENTS.md` and are not restated here.

Ground truth: current stable is **Rust 1.99.0** (2026-10-01) and the current
edition is **Edition 2024** (`edition = "2024"` in `Cargo.toml`; the edition
shipped with Rust 1.85.0, RFC 3501 — see
<https://doc.rust-lang.org/edition-guide/rust-2024/index.html>). The official
docs hub ("The Rust Bookshelf") is <https://doc.rust-lang.org/> — The Book,
Rust By Example, std API docs, The Reference, the Style Guide, the Cargo Book,
the Rustdoc Book, the Clippy Book, the rustc Book, the Edition Guide, the
Rustonomicon, and the Embedded Rust Book all live there.

Labels used below and in the siblings: **[official]** = backed by rust-lang.org
docs, **[convention]** = this repo's team rule, **[ecosystem]** = third-party
crate guidance backed by that crate's own docs.

## Build System

- **Toolchain**: rustup-managed stable. Pin per repo with a `rust-toolchain.toml`
  at the crate/workspace root — never hardcode a version separately in CI config
  or a Dockerfile (same rule as Go's `go.mod`, see docs/CI_CD.md §Toolchain Versions).
- **Edition**: `edition = "2024"` in every `Cargo.toml`. **[official]** Migrate
  existing crates with `cargo fix --edition` (Edition Guide).
- **Workspaces**: multi-crate repos use one `[workspace]` root — a single shared
  `Cargo.lock` and a single shared `target/` directory. **[official]**
  <https://doc.rust-lang.org/stable/book/ch14-03-cargo-workspaces.html>. Set
  `resolver = "3"` explicitly at the workspace root; it is the Edition 2024
  default and requires Rust 1.84+
  (<https://doc.rust-lang.org/cargo/reference/resolver.html>). **[official]**
- **Profiles**: `cargo build` uses the `dev` profile (opt-level 0),
  `cargo build --release` the `release` profile (opt-level 3); customize via
  `[profile.*]` in `Cargo.toml`. **[official]**
  <https://doc.rust-lang.org/stable/book/ch14-01-release-profiles.html>
- **Thin binary + library crate**: a service is a library crate (`src/lib.rs`)
  plus a small `src/main.rs` that only wires dependencies and starts the
  runtime. The Book recommends exactly this so integration tests in `tests/`
  can target the library — binary-only crates cannot be integration-tested.
  **[official]** <https://doc.rust-lang.org/stable/book/ch11-03-test-organization.html>

## Commands

| Command | What it does |
|---|---|
| `cargo build` | Debug build (`dev` profile) |
| `cargo build --release` | Optimized build (`release` profile) |
| `cargo run` | Run the binary; `cargo run -p <crate>` selects a workspace member |
| `cargo test` | Runs unit tests, `tests/` integration tests, **and doc-tests** |
| `cargo test -p <crate>` | Test one workspace member |
| `cargo test --doc` | Doc-tests only |
| `cargo fmt` | Format with rustfmt (implements the Rust Style Guide defaults) |
| `cargo fmt --check` | Fail if any file is unformatted — the CI formatting gate |
| `cargo clippy --all-targets -- -D warnings` | Lint gate — warnings are errors in CI |
| `cargo doc --open` | Build and browse rustdoc API documentation locally |
| `cargo fix --edition` | Official edition-migration helper **[official]** |
| `cargo audit` | RustSec advisory scan of `Cargo.lock`. **Not built into Cargo** — third-party subcommand, requires `cargo install cargo-audit` (<https://rustsec.org/>) **[ecosystem]** |

## Project Structure

Single-crate service (the common case). Layer names map onto
docs/ARCHITECTURE.md's controller → service → repository stack **[convention]**;
the `main.rs`/`lib.rs` split and `tests/common/mod.rs` are official Rust
conventions **[official]**:

```
my-service/
├── Cargo.toml               # edition = "2024", pinned deps
├── rust-toolchain.toml      # channel = "stable" (or an exact version)
├── clippy.toml              # optional shared clippy configuration
├── src/
│   ├── main.rs              # THIN: runtime init, config load, wiring, serve
│   ├── lib.rs               # crate root — all real logic lives in the library
│   ├── api/                 # controller layer: routes, handlers, DTOs,
│   │                        #   error → HTTP status mapping, /health
│   ├── services/            # business logic — depends on repository TRAITS
│   ├── repositories/        # data access: trait defs + concrete impls
│   ├── domain/              # domain types / value objects (no I/O)
│   ├── clients/             # upstream service clients (behind traits)
│   ├── middleware/          # request ID, trace propagation, auth
│   ├── config.rs            # env → one typed Config struct, fail fast
│   └── error.rs             # the crate's typed error enum
└── tests/                   # integration tests — each file is its own crate
    ├── common/mod.rs        # shared helpers (mod.rs so it is NOT a test target)
    └── health_test.rs
```

Multi-crate workspace:

```
workspace-root/
├── Cargo.toml               # [workspace] resolver = "3", members = [...]
├── Cargo.lock               # ONE lockfile shared by the whole workspace
├── crates/
│   ├── domain/              # pure domain types, no I/O deps
│   ├── service/             # business logic
│   └── server/              # binary crate: api layer + wiring
└── target/                  # ONE shared build directory
```

Split into workspace crates when a layer needs independent compilation or
reuse, not preemptively (YAGNI — docs/CODING_CONVENTIONS.md §Design Principles).

## Linting & Formatting

- **rustfmt** implements the official Rust Style Guide defaults: spaces not
  tabs, 4-space indentation, 100-char max line width, block indent over visual
  indent, trailing commas in multi-line lists. **[official]**
  <https://doc.rust-lang.org/stable/style-guide/index.html>. Do not fight the
  formatter. The one sanctioned `rustfmt.toml` setting is
  `style_edition = "2024"`, which pins formatting to the Edition 2024 style
  instead of the toolchain default **[official]**
  <https://doc.rust-lang.org/edition-guide/rust-2024/rustfmt-style-edition.html>.
  Any other per-repo `rustfmt.toml` fork needs a documented reason.
- **Clippy** is the lint gate: `cargo clippy --all-targets --all-features
  -- -D warnings` must be clean in CI. `--all-features` matters — a feature
  combination that is never compiled is never linted. Lint categories and
  default levels (correctness = deny; suspicious/style/complexity/perf = warn;
  pedantic/restriction/nursery/cargo = allow) are documented at
  <https://doc.rust-lang.org/stable/clippy/index.html>. **[official]**
- Enable the `restriction` lints that encode this repo's always-rules in each
  crate root or `clippy.toml`: `clippy::unwrap_used`, `clippy::expect_used`
  (allow-listed in `#[cfg(test)]` code), `clippy::todo`. **[convention]**
- **Supply chain**: `cargo deny check` for licence, ban, advisory and sources
  policy, plus `cargo audit` against the RustSec DB. cargo-deny "lets you lint
  your project's dependency graph to ensure all your dependencies conform to
  your expectations and requirements" **[ecosystem]**
  <https://embarkstudios.github.io/cargo-deny/>, with a maintained Action
  (`EmbarkStudios/cargo-deny-action@v1`). Neither is part of the Rust
  toolchain — both are third-party subcommands that must be installed, and CI
  must fail if they are missing rather than skip silently.
- **Reproducible CI**: build and test with `--locked` (`cargo build --locked`,
  `cargo test --locked`) so CI fails when `Cargo.lock` would change instead of
  quietly resolving newer versions. `--locked` is a documented Cargo flag
  **[official]** <https://doc.rust-lang.org/stable/cargo/index.html>, and is
  the form rust-lang uses in its own CI guidance.
- **Complexity gate**: the repo-wide rule is cyclomatic complexity ≤6 per
  function (docs/CODING_CONVENTIONS.md §Design Principles). Java enforces it
  with PMD, Go with golangci `cyclop`/`gocognit`. **Rust has no official
  mechanical cyclomatic-complexity lint.** Clippy ships
  `clippy::cognitive_complexity` — verified in the official lint list
  (<https://rust-lang.github.io/rust-clippy/master/index.html#cognitive_complexity>):
  `restriction` group, **allow by default**, default threshold **25**
  (configurable via `cognitive-complexity-threshold` in `clippy.toml`). It
   measures cognitive complexity at a much looser default, so it is an advisory
   aid, not an equivalent gate. `scripts/check-code-principles.sh` **does** now
   scan `*.rs` (ADR 0006 D1), but during that ADR's D6 warn phase Rust findings
   are emitted as **approximate warnings and never change the exit status** — so
   the gate cannot yet block a Rust PR. Treat ≤6 as review-enforced, with the
   script's warnings and `-W clippy::cognitive_complexity` at a tightened
   threshold as the mechanical signals. Rust complexity counting is genuinely
   approximate: `match` arms, generic bounds and closures inflate naive counts,
   and the script says so in every warning it emits. Promotion to blocking is a
   one-line change (`WARN_ONLY_LANGS` in that script) once the thresholds are
   calibrated against real repos.
   **[official lint; convention usage; gate behaviour per ADR 0006]**

## Always-Rules

1. **Recoverable errors are `Result<T, E>` values with a typed error enum.**
   `panic!` is only for broken invariants / bugs. The Book's recoverable-vs-
   unrecoverable split is authoritative:
   <https://doc.rust-lang.org/stable/book/ch09-00-error-handling.html>. **[official]**
2. **No `unwrap()` / `expect()` in production code paths.** Fine in tests,
   examples, and prototypes; `expect` is acceptable only where a documented
   invariant guarantees success (see PATTERNS.md §unwrap discipline and
   <https://doc.rust-lang.org/stable/book/ch09-03-to-panic-or-not-to-panic.html>). **[official basis, convention rule]**
3. **Trait-based dependency injection; no global state.** Dependencies are
   constructor-injected behind traits (generics or `Arc<dyn Trait>`). Global
   `static mut`, `lazy_static`, and hidden-global service locators are banned by
   the root AGENTS.md DI rule — and Edition 2024 rejects references to
   `static mut` outright
   (<https://doc.rust-lang.org/edition-guide/rust-2024/static-mut-references.html>). **[official + convention]**
4. **No `unsafe` without justification, a `// SAFETY:` comment on every block,
   and explicit reviewer sign-off.** Read the Rustonomicon first:
   <https://doc.rust-lang.org/stable/nomicon/index.html>. **[convention]**
5. **`edition = "2024"` everywhere**; new workspaces use `resolver = "3"`.
6. **`cargo fmt --check` and `cargo clippy -- -D warnings` clean on every PR.**
7. **Every `pub` item has a `///` doc comment with a runnable example where
   practical** — doc-tests execute on every `cargo test`, so documentation
   cannot rot. **[official]**
   <https://doc.rust-lang.org/stable/rustdoc/write-documentation/documentation-tests.html>
8. **Services commit `Cargo.lock`**; pin dependency versions in a
   `[workspace.dependencies]` table, never float ranges per crate
   (docs/SECURITY.md §Dependency Management). Scan with `cargo audit` in CI. **[convention]**
9. **Structured logging with trace IDs** at service-method boundaries
   (docs/OBSERVABILITY.md); `tracing` is the default facade — see PATTERNS.md. **[convention/ecosystem]**
10. **No secrets in source or `Cargo.toml`**; `.env` (gitignored) for small
    projects, secrets manager at `production` tier (docs/SECURITY.md §Secrets Management). **[convention]**

## Read in Order

1. [`PATTERNS.md`](./PATTERNS.md) — error handling (thiserror/anyhow split),
   unwrap discipline, ownership/borrowing, trait-based DI, layering, async
   runtime + `Send`/`Sync`, logging, unsafe policy, Edition 2024 checklist.
2. [`TESTING.md`](./TESTING.md) — the layered pyramid mapped onto `#[test]`,
   `tests/`, doc-tests, `#[tokio::test]`, trait-based fakes, property and
   mutation testing tiers.
3. [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) — layer responsibilities.
4. [`docs/CODING_CONVENTIONS.md`](../../docs/CODING_CONVENTIONS.md) — design
   principles, complexity budget, Result-type philosophy.
5. [`docs/SECURITY.md`](../../docs/SECURITY.md) — read before writing any
   `unsafe`, secret-loading, or input-validation code.

## Adoption

For a child repo adopting this standard:

1. Add `rust-toolchain.toml` (stable channel) and set `edition = "2024"` in
   every `Cargo.toml`; run `cargo fix --edition` on older crates.
2. Restructure to the thin-binary + library-crate layout above; name modules
   `api/`, `services/`, `repositories/`, `domain/`.
3. Wire CI: `cargo fmt --check` → `cargo clippy --all-targets -- -D warnings`
   → `cargo test` → `cargo audit` (install the `cargo-audit` binary in the CI
   image; it is not part of Cargo).
4. Add `clippy.toml` + crate-root lint attributes for `unwrap_used` /
   `expect_used` / `cognitive_complexity` (advisory threshold).
5. Declare the conformance tier (docs/CONFORMANCE_TIERS.md); property and
   mutation testing apply at `production` tier only.

**Rust saga/outbox coverage now exists** (ADR 0006 D2+D3).
`scripts/detect-saga-outbox.sh` scans `.rs`, and all four gates understand Rust
idioms: `tokio::time::timeout` for step timeouts, a `compensate` fn or
`impl Compensable` for compensation, `sqlx`/`diesel` `.sql` migrations for the
outbox schema — the 7 required columns and the partial index on
`published_at IS NULL` are unchanged, not relaxed — and `OutboxRelay` /
`outbox_relay` plus a snake_case dedup store for the relay. Integration tests
must live in `tests/*saga*.rs` or `tests/*outbox*.rs`; inline `#[cfg(test)]`
unit-test modules do **not** satisfy that gate. CI wiring is
`ci/templates/child-ci-rust.yml`, mutation config `ci/templates/mutants.toml`.
These token patterns are **house convention**, not mandates from
`docs/SAGA_PATTERN.md` / `docs/OUTBOX_PATTERN.md`, which specify behaviour
rather than spellings.
