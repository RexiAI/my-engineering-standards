# Architecture Decision Record (ADR)

## Title

Extend the gate catalog to Python and Rust without adding gate names

## Status

Proposed

## Context

PR #80 added four language guides — Angular v22, Ionic v9, Python/FastAPI 0.143.1
and Rust 1.99 — under `language-specific/`. Verifying what the repo's mechanical
gates actually cover, rather than what the docs claimed, found that the gate
catalog stops at Java, Go and JS/TS. Four defects, each confirmed by reading the
script at the cited line:

1. **`scripts/check-code-principles.sh` never analyses Python or Rust.** Lines
   307–309 enumerate exactly `*.java`, `*.go` and `*.ts`/`*.tsx`/`*.js`/`*.jsx`.
   Line 311 then calls `finish_clean` with *"No Java, Go, or JS/TS source files
   found — nothing to check"*, exiting **0**. A Python-only or Rust-only child
   repo therefore passes the design-principles gate without being analysed at
   all. `docs/CODING_CONVENTIONS.md` lines 79 and 161 describe this script as
   applying the threshold "language-agnostically", which is what the new Rust
   guide inherited before it was corrected.

2. **`scripts/detect-saga-outbox.sh` cannot see Python or Rust.** Its
   `CODE_FILES` filter is `\.(java|go|ts|js|sql|xml)$` (line 79) and its
   migration-name case allows only `*.java|*.go|*.ts|*.js|*.sql|*.xml` (line 69).
   Saga or outbox code in a FastAPI or Rust service leaves `SAGA_DETECTED` and
   `OUTBOX_DETECTED` false, so every downstream gate skips. A silent skip is
   indistinguishable from a pass in CI output.

3. **All four downstream gates are hardcoded to Java/Go/Node.**
   `check-saga-timeouts.sh` matches `WithTimeout`/`.go`; `check-saga-tests.sh`
   matches `.go|.ts|.java`; `lint-outbox-schema.sh` and `check-outbox-relay.sh`
   match `.java|.go|.js|.ts`. This creates an ordering constraint: extending
   detection (defect 2) **without** teaching the gates those languages would flip
   Python/Rust repos from silently-skipped to **false failures**, because the
   gates would search for idioms those languages do not express. Detection and
   gates must move in the same change.

4. **No Python or Rust CI assets exist.** `ci/templates/` ships
   `child-ci-{java,go,node,react-native}.yml`, `pitest-profile.xml` (Java),
   `stryker.conf.json` and `stryker.react-native.conf.json` (JS/TS),
   `pact-{java,go,node}.yml`, and `archunit/`, `eslint-saga-rules/`,
   `go-saga-lint.go`. There is no Python or Rust equivalent of any of them.
   `ci/gitlab/frontend/ci-angular.yml` does exist and is runner-agnostic, so
   Angular needs no new template.

Two invariants constrain the fix. `scripts/check-gate-consistency.sh` extracts
the canonical design-principles gate list from `check-code-principles.sh`'s
`valid_gate()` (line 225: `complexity`, `dry`, `yagni`, `solid`,
`component-per-file`, `property-tests`) and its Check 4 hard-asserts the count is
**6** — so the gate *names* must not change, only the languages they analyse.
And `finish_clean` is a shared helper in
`scripts/check-common.sh`, used by several gates and covered by
`scripts/tests/check-common.bats:32`, so its exit-0 contract must not be altered
globally; any change belongs in the caller.

`docs/GOVERNANCE.md §ADR Requirement` makes an ADR mandatory for any change to
the gate catalog before it merges. This is that ADR.

## Decision

Extend the existing gates' **language coverage** to Python and Rust. Do not add
gate names, do not change the count of 6, and do not alter the shared
`finish_clean` contract.

- **D1 — `check-code-principles.sh` gains `PY_FILES` (`*.py`) and `RS_FILES`
  (`*.rs`)**, wired through the same per-language `case "$lang"` branches that
  already serve Java, Go and JS/TS. The line-311 early-exit condition gains the
  two new sets. Gate names and the canonical list are untouched, keeping
  `check-gate-consistency.sh` green. Five of the six gates apply to both new
  languages (`complexity`, `dry`, `yagni`, `solid`, `property-tests`);
  `component-per-file` is a JS/TS component-model concept and **stays scoped to
  JS/TS** — it must not be extended to Python or Rust merely to make the count
  uniform.
- **D2 — `detect-saga-outbox.sh` patterns extended to `.py` and `.rs`**, in the
  same commit as D3 and never before it.
- **D3 — the four saga/outbox gates learn Python and Rust idioms.** Timeouts:
  Python `asyncio.timeout`/`asyncio.wait_for`/`httpx` timeout kwargs, Rust
  `tokio::time::timeout`/`Duration` bounds. Compensation: Python decorator or
  `compensate=` kwarg on the step registration, Rust a `compensate` fn or
  `impl Compensable`. Outbox schema and relay checks extended to Alembic/
  `sqlmodel` migrations and `sqlx`/`diesel` migrations respectively.
- **D4 — new CI assets**: `ci/templates/child-ci-python.yml` (uv, ruff,
  mypy --strict, pytest with a coverage floor, bandit) and
  `ci/templates/child-ci-rust.yml` (`cargo fmt --check`,
  `clippy --all-targets --all-features -- -D warnings`, `cargo test --locked`,
  `cargo audit`, `cargo deny check`), plus mutation configs — `mutmut` for
  Python and `cargo-mutants` for Rust — gated at the `production` conformance
  tier per `docs/CONFORMANCE_TIERS.md`. Contract-test templates only if a child
  repo actually needs them (YAGNI).
- **D5 — a zero-file scan must not read as a pass, but must not hard-fail
  either.** The `finish_clean` message is changed to enumerate exactly which
  extensions were scanned, so a repo in an uncovered language visibly reports
  "scanned for java/go/ts/js/py/rs, found none" instead of implying coverage. A
  new opt-in `--require-language <lang>` flag exits 1 when the caller expects a
  language and none was found, for child repos that know what they are.
- **D6 — rollout is two-phase.** New language coverage lands as `warn` for one
  release, then becomes `blocking`. Python and Rust child repos currently pass
  these gates by not being scanned; flipping straight to blocking would fail
  them on their first standards bump with no opportunity to remediate.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| **A. Hard-fail whenever zero supported files are found** | Simple; kills the silent-pass class outright, mirroring the `total_scored == 0` false-pass fix seen in the wild | Breaks docs-only repos and any repo in an uncovered language (Ruby, C#, Kotlin). Produces false failures, so it would be reverted. **Rejected** |
| **B. Extend detection only (defect 2), defer the gates** | Two-line regex change; cheap | Verified to produce **false failures**: all four downstream gates are Java/Go/Node-specific, so a detected Python saga runs gates looking for `WithTimeout` and `@Transactional`. Strictly worse than the status quo. **Rejected** |
| **C. Separate per-language scripts (`check-python-principles.sh`, `check-rust-principles.sh`)** | Avoids touching a 1111-line script; independently testable | Duplicates the six-gate logic four ways and destroys the single-source-of-truth invariant that `check-gate-consistency.sh` exists to protect — the exact drift that caused PR #59's CI failure. **Rejected** |
| **D. Extend `check-code-principles.sh` in place + opt-in strict flag + warn-then-block rollout (chosen)** | Preserves the single canonical gate list and the `finish_clean` contract; no false failures; coverage becomes real | The script grows; complexity/DRY/SOLID heuristics need calibration for Python (comprehensions, decorators) and Rust (generics, `match` arms, closures) before they can block |

## Consequences

**Easier:** Python and Rust child repos get genuine mechanical gate coverage for
the first time. The "exit 0 having scanned nothing" defect class shrinks, and the
new guides' claims about enforcement become true rather than aspirational.

**Harder:** `check-code-principles.sh` grows further past 1100 lines and now
carries five language branches. Its characterization tests
(`scripts/tests/check-code-principles.bats`, `check-code-principles-blame.sh`,
`check-code-principles.selftest.bats`) must be extended per language, and
`check-code-principles.bats:191` already asserts against the current
"No Java, Go, or JS/TS source files found" string — that assertion must be
updated in the same change or CI goes red.

**Constrains:** the design-principles gate list stays frozen at six names,
enforced by `check-gate-consistency.sh` Check 4. Any future language is added by
extending these branches, not by forking a parallel script (Alternative C).

**Accepted risk:** heuristic cyclomatic-complexity measurement is least reliable
exactly where Python and Rust differ most from Java/Go — comprehensions and
decorator stacks in Python, generic bounds and `match` arms in Rust. Thresholds
must be calibrated against real child repos during the D6 warn phase before
blocking is enabled, or the gate will train teams to add suppressions.

**Note on Rust complexity specifically:** even after D1, Rust has no *official*
complexity lint. `clippy::cognitive_complexity` is in the `restriction` group,
allow-by-default at threshold 25, and the Clippy team's own documentation now
expresses doubt about the metric. D1's heuristic is therefore a house
approximation, not an industry-standard measurement — which is precisely why it
needs a warn phase.

## Compliance

- `scripts/check-gate-consistency.sh` must exit 0 (canonical gate list and count
  of 6 unchanged).
- `scripts/check-bats-assertions.sh` must exit 0 — no vacuous assertions in the
  new per-language tests.
- New bats coverage required for: a Python file and a Rust file each triggering
  the complexity gate; `--require-language` exiting 1 on absence and 0 on
  presence; a Python saga with and without a timeout; a Rust outbox migration
  with and without the required columns and partial index.
- `scripts/tests/check-common.bats` must remain unmodified and green, proving the
  shared `finish_clean` contract was not altered.
- The full suite runs in `.github/workflows/self-ci.yml`; the four repo
  validators (`check-skills.sh`, `check-orchestration.sh`, `check-model-env.sh`,
  `check-governance.sh`) must stay green.
- D6 rollout is verified by confirming the warn phase emits diagnostics without
  changing exit status, in at least one real Python and one real Rust child repo,
  before blocking is enabled.

## Notes

- 2026-10-15: Decision recorded. Status **Proposed** — implementation has not
  started. The verified findings that prompted it are duplicated in
  `docs/OFFICIAL_REFERENCES.md §Findings that constrain our guides` so they stay
  visible to anyone refreshing a language guide.
- Implementation is deliberately **not** in PR #80. That PR is documentation
  (+7.8k lines) and is already awaiting review; mixing a change to a 1111-line
  gate script, four saga gates, two new CI templates and their characterization
  tests into it would make both unreviewable. This ADR ships in PR #80 because
  governance requires it recorded before the gate change merges, and because the
  findings it rests on were produced by that PR's research. The gate work lands
  as a separate stacked change referencing this ADR.
