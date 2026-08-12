# Tasks — Gate self-tests + run telemetry

Formalization of `specs/012-gate-selftests-telemetry/00-informal.md`. Two
model-free capabilities:

1. **Self-tests** for the gate scripts — throwaway fixtures, one per gate, that
   prove each gate actually fires (and fires with the right severity), wired into
   `.github/workflows/self-ci.yml`. Prevents the "gate exists but never fires"
   regression class.
2. **Run telemetry** — an append-only `runs.jsonl` per repo recording one entry
   per pipeline run, and a `scripts/gate-stats.sh` that prints failure/retry
   rates. The drift signal the architecture exists to catch.

## Grounded reality (verified against this repo by executing the real scripts)

All findings below were verified by actually running the real scripts against
scratch fixtures in `/tmp` on this checkout, not inferred from reading.

### `scripts/check-code-principles.sh` — the gates as they exist today

The script's five gate categories (lines 498-533) and their empirically confirmed
severities and exit codes:

| Gate | What fires | Severity | Exit |
|---|---|---|---|
| Complexity | cyclomatic complexity >6 (CC counted from if/for/while/switch/catch/case/&&/\|\|/ternary) | **FAIL** | 1 |
| KISS | method body >20 lines (`KISS_LINES`) | WARN | 0 |
| KISS | method with >6 parameters (`KISS_PARAMS`) | WARN | 0 |
| DRY | identical 4-line block in 2+ places | WARN | 0 |
| YAGNI | interface with exactly one implementation | **FAIL** | 1 |
| YAGNI | empty method body `{ }` in non-test code | WARN | 0 |
| SOLID-SRP | god file: >15 methods or >400 lines | WARN | 0 |
| SOLID-OCP | `switch` with ≥4 cases, or ≥4 `else if` | WARN | 0 |
| SOLID-LSP | ≥3 `instanceof` in one file | WARN | 0 |
| SOLID-ISP | interface with >5 methods | WARN | 0 |
| SOLID-DIP | domain/engine file imports store/infra/repository | **FAIL** | 1 |
| Property tests | at `production` tier, language has source but no property-test framework usage | **FAIL** | 1 |

With `--warn-as-error`, every WARN becomes a FAIL (exit 1) — the mechanism a
selftest uses to prove a finding is really a WARN and not a FAIL: a WARN fixture
exits 0 by default and 1 under `--warn-as-error`; a FAIL fixture exits 1 either
way.

- Flag surface today: `--tier mvp|production|multi-service`, `--warn-as-error`
  (double-dash kebab style, lines 69-76), positional `SOURCE_DIR`. Any `-*`
  argument is rejected as "Unknown option" with exit 2 (line 73).
- `--gates <comma-list>` (scoped categories `complexity`/`dry`/`yagni`/`solid`/
  `property-tests`) and `--json` are **not merged yet** — they come from spec 007
  (`specs/007-verifier-discipline/10-tasks.md` Task 3). The 012 selftest depends
  on `--gates` existing for fixture isolation (see Cross-spec seams below).

### `scripts/check-scenario-traceability.sh`

- Positional `SPECS_DIR` / `SOURCE_DIR` only (lines 30-31); two checks: (1) every
  `## AC-NNN-NN` heading in `specs/*/20-acceptance/` is referenced by a test
  (lines 62-71), (2) every `AC-NNN-NN` reference resolves to a real heading
  (lines 75-83). Exit 0 clean, 1 violations; early-exit 0 when nothing to check.
- **Not executable** (`-rw-r--r--`, unlike `check-code-principles.sh` which is
  `-rwxr-xr-x`). It is invoked via `bash`. The 012 selftest must invoke it via
  `bash` to be robust regardless of the +x bit. (Whether to add +x is a
  maintenance question for the Coder, not a task here.)
- Selftest feasibility: confirmed. A pass fixture (heading + test referencing it)
  exits 0 with "traced to a test"; an orphan fixture (heading, no reference)
  exits 1 with "no test references it"; a dangling fixture (test cites a bogus
  ID) exits 1 with "no matching scenario heading exists".

### `.github/workflows/self-ci.yml`

One `validate` job with steps: CRLF check on committed blobs, `bash -n` over all
`*.sh`, `make validate-all`, `make lint`, shellcheck (continue-on-error), YAML
syntax check. The `bash -n` step automatically parses any new `*.sh` scripts the
012 spec adds; the selftest step is a new step in this job.

### `agents/spec-verifier.md`

- Runs checks 1 (traceability), 2 (test suite), 3 (complexity linter), 3.5
  (design-principles), 4 (spot check), 5 (unaccounted behavior). Report contract
  writes `specs/NNN-slug/25-verification.md` with a PASS/FAIL verdict.
- `permission.edit` allows only `specs/*/25-verification.md`; `permission.bash`
  allows everything. So appending a telemetry record must go through a helper
  script (`scripts/record-gate-run.sh`) called via bash — **no frontmatter change
  is needed**, and this is the sanctioned path that keeps the "verifier writes
  nothing but the report + scratch" discipline intact.

### `agents/spec-pipeline.md` (orchestrator)

Delegates `/build` stages in order: Coder → Refactorer → Verifier → Mutation
Runner → PR Opener. It is where loop/retry counts for the current run are known
or tracked (they exist today only as spec 008's budgets, not yet as tracked
numbers in this file).

### Cross-spec seams

- **007** (`verifier-discipline`): adds `--gates`/`--json` and exit-code 2 to
  `check-code-principles.sh`, `--checks`/`--json` and exit 2 to
  `check-scenario-traceability.sh`. **012's selftest requires 007's `--gates`**:
  ordering dependency — 012 must land after (or in the same batch as) 007, and
  the selftest fails fast with a clear message if `--gates` is absent.
- **011** (`design-gate-blame-scoping`): adds `-BaseRef <ref>` (blame scoping) to
  `check-code-principles.sh`. `-BaseRef` is 011's flag for classification, not a
  telemetry flag. **012 does not re-add it.** The informal AC-002's
  "`-ReportPath`/`-BaseRef`" listing splits across specs: 012 adds only
  `-ReportPath`.
- **008** (`remediation-budget`): defines Phase 1 (pre-PR) / Phase 2 (post-PR)
  budgets of max 3. 012's telemetry `loopCount`/`phase1Retries`/`phase2Retries`
  fields are the audit trail for those budgets (008 AC-004 wants retry counts
  auditable); the values come from the orchestrator's tracking.
- Flag-style split is a real seam: 007 uses double-dash (`--gates`, `--json`),
  011/012 use single-dash (`-BaseRef`, `-ReportPath`). The current parser rejects
  `-*`. The Coder/Architect must reconcile one parser accepting both forms, or
  the batch's specs must standardize on one style (see Open questions 1).

## Tasks

### Task 1 — `scripts/check-code-principles.selftest.sh`: one fixture per gate, assert fire + severity

A bash script (model-free, no new dependencies: bash + `mktemp` + `grep` +
`awk`/`find`, all present in the self-ci `ubuntu-latest` image) that proves every
gate in `check-code-principles.sh` fires, with the right severity, on a
deliberately-bad fixture — and does **not** fire on a clean/near-miss control.

Acceptance criteria:
- Creates fixtures in a `mktemp -d` scratch root (never inside the repo), one
  fixture per row of the table below, runs the real checker against each with
  `--gates <category>` for isolation, and asserts (a) the expected finding
  substring appears in stdout, (b) the exit code matches the severity: FAIL
  findings exit 1, WARN findings exit 0 by default and exit 1 under
  `--warn-as-error` (this is what proves the severity is WARN, not FAIL), (c) the
  clean/near-miss controls exit 0 with no matching finding.
- Fixture table (contents in `20-acceptance/AC-012-01-principles-selftest.md`):
  - `complexity` → `--gates complexity`: `cc-bad` (a method with 7 `if`s,
    verified CC=8) → `Cyclomatic complexity >6` FAIL, exit 1; `cc-clean` (5 `if`s,
    CC=6) → no finding, exit 0; `kiss-lines` (a 22-line method body, no
    conditionals) → `Method body >20 lines` WARN; `kiss-params` (7 parameters) →
    `Method with >6 parameters` WARN.
  - `dry` → `--gates dry`: `dry-bad` (identical 4-line block in two files) →
    `Possible duplication` WARN; `dry-clean` (two similar-but-not-identical
    blocks) → no finding, exit 0.
  - `yagni` → `--gates yagni`: `yagni-single-impl` (interface + exactly one
    `implements`) → `has exactly one implementation` FAIL, exit 1;
    `yagni-empty-body` (method body `{ }`) → `Empty method body` WARN.
  - `solid` → `--gates solid`: `srp` (16 non-empty methods) → `SRP: possible god
    file` WARN; `ocp` (switch with 4 cases) → `OCP: type-dispatch switch` WARN;
    `lsp` (3 `instanceof`) → `LSP:` WARN; `isp` (interface with 7 methods) →
    `ISP: fat interface` WARN; `dip` (a file under a `domain/` directory that
    imports a `repository.*` package) → `DIP: domain/engine code imports` FAIL,
    exit 1.
  - `property-tests` → `--gates property-tests --tier production`: `prop-bad` (a
    Go source file, no `testing/quick`) → `Property tests (go): no testing/quick`
    FAIL, exit 1; `prop-clean` (a `_test.go` using `testing/quick`) → no finding,
    exit 0.
  - `clean-tree` (no `--gates`, default tier mvp, a small well-formed Java file):
    full run → no FAIL/WARN, exit 0.
- SRP/OCP fixtures avoid empty `{ }` method bodies so they don't cross-trigger the
  YAGNI empty-body WARN (verified: `public void m1() { work(1); }` and inline
  `System.out.println(...)` bodies stay clean; `{ }` bodies do not).
- Invokes the checker as `bash "$CHECKER"` (robust regardless of +x) with
  `SOURCE_DIR` set to the fixture dir and cwd-independent `$0`-relative script
  resolution.
- Exits 0 only if every fixture/control assertion passes; on any failure prints
  the failing fixture name, the actual output, and the expected assertion, and
  exits 1.
- If the checker does not support `--gates` (i.e. the first `--gates` invocation
  errors with `Unknown option: --gates` / exit 2), the selftest prints a clear
  "requires spec 007's --gates flag" message and exits non-zero — this is the
  documented 012←007 ordering dependency, surfaced loudly rather than silently
  mis-run.
- Cleans up the scratch root via a `trap`.

Scenarios: `20-acceptance/AC-012-01-principles-selftest.md`

### Task 2 — `scripts/check-scenario-traceability.selftest.sh`: pass / orphan / dangling

A bash script proving both traceability checks work in both directions.

Acceptance criteria:
- Builds three scratch trees in `mktemp -d` (specs and source as sibling
  directories so the source scan never includes the specs dir):
  - `pass`: `specs/999-slug/20-acceptance/AC-999-01-traced.md` with a
    `## AC-999-01 — widget renders` heading, plus a `src/widget_test.go`
    containing `TestWidget_AC_999_01` → exit 0, output contains
    `AC-999-01 — traced to a test`.
  - `orphan`: a `## AC-999-02 —` heading with no reference anywhere in `src` →
    exit 1, output contains `no test references it`.
  - `dangle`: a traced heading (`## AC-999-03 —`) plus a `src/widget_test.go`
    citing `TestBogus_AC_888_88` → exit 1, output contains
    `no matching scenario heading exists`.
- Invokes the checker as `bash "$CHECKER" "$SPECS_DIR" "$SOURCE_DIR"` (positional
  form — it has no flags today; the `--checks` scoped flag is 007's and is not
  required here).
- Exits 0 only if all three cases produce their expected exit code and message;
  otherwise names the failing case and exits 1. Cleans up via `trap`.

Scenarios: `20-acceptance/AC-012-02-traceability-selftest.md`

### Task 3 — Wire both selftests into `.github/workflows/self-ci.yml`

Add one step to the existing `validate` job so both selftests run on every push
and PR, and fail the job if either finds a regression.

Acceptance criteria:
- A new step (after the shellcheck step) runs:
  `bash scripts/check-code-principles.selftest.sh` and
  `bash scripts/check-scenario-traceability.selftest.sh` in a single `run:` block.
- Either selftest exiting non-zero fails the job (no `continue-on-error`).
- The existing `bash -n` step automatically covers the new `*.sh` scripts; the
  shellcheck step's `scripts/*.sh` glob also picks them up (that step is
  continue-on-error today — unchanged).

Scenarios: `20-acceptance/AC-012-03-selfci-wiring.md`

### Task 4 — `-ReportPath <file>` on both gate scripts (telemetry output)

Add a single-dash `-ReportPath <file>` flag to `scripts/check-code-principles.sh`
and `scripts/check-scenario-traceability.sh`. When given, each script writes its
machine-readable JSON report (the same content its `--json` mode emits to stdout)
to `<file>`. This is the informal AC-002 "gate scripts accept a `-ReportPath` for
telemetry output" — `-BaseRef` belongs to spec 011 and is **not** added here.

Acceptance criteria:
- `-ReportPath <file>` writes a single JSON object to `<file>` — the same fields
  as the script's `--json` stdout mode (for `check-code-principles.sh`: `tier`,
  `gates`, `fails`, `warns`; for `check-scenario-traceability.sh`: `passes`,
  `fails`) — regardless of whether `--json` is also passed. Human-readable stdout
  is unchanged.
- The file is written atomically (write a temp sibling, then `mv`) so a concurrent
  or partial read never sees a half-written report.
- Combines freely with the existing flags (`--tier`, `--warn-as-error`, `--gates`
  on the principles script; positional `SPECS_DIR`/`SOURCE_DIR` on the traceability
  script) and with 011's `-BaseRef` where merged, without colliding.
- Missing/empty `<file>` value → stderr message, exit 2 (the 007-defined
  could-not-run code).
- Default behavior with no `-ReportPath` is unchanged.

Scenarios: `20-acceptance/AC-012-04-report-path.md`

### Task 5 — `scripts/record-gate-run.sh`: append-only runs.jsonl writer

A model-free bash script the Verifier calls to append exactly one telemetry record
per pipeline run.

Acceptance criteria:
- Usage: `record-gate-run.sh -record '<json>' [-f <file>]` (or the record on
  stdin). Default file: `<repo-root>/runs.jsonl`; `-f` or the `GATE_RUNS_FILE`
  env var overrides it. `runs.jsonl` is tracked in git (the trend is the point —
  it survives merges and feeds the weekly view), one JSON object per line,
  appended with `>>` (append-only; never rewritten, no dedup, no sort).
- Record schema (all keys required except where noted):
  ```
  {
    "runId": "uuid",
    "specSlug": "012-gate-selftests-telemetry",   // XOR jiraKey — exactly one
    "gatesFailed": ["design-principles"],
    "loopCount": 2,
    "phase1Retries": 1,
    "phase2Retries": 0,
    "warnings": ["..."],
    "durationSec": 123.4,
    "outcome": "pass" | "fail" | "block"
  }
  ```
  Gate IDs for `gatesFailed` follow the Verifier's checks: `traceability`,
  `test-suite`, `complexity`, `design-principles`, `spot-check`,
  `unaccounted`. `outcome` precedence: `block` if any gate BLOCKed, else `fail`
  if any FAILed, else `pass`.
- Validation without `jq` (007's BLOCK example names `jq` as a possibly-missing
  tool — 012 must not add it as a hard dependency): the record must be a single
  line with balanced braces, must contain each required key name, `outcome` must
  be one of the three values, and exactly one of `specSlug`/`jiraKey` must be
  present. Violations → stderr message naming the field, exit 1, nothing appended.
- `runId` is generated by the script (`uuidgen`, falling back to
  `<epoch-nanos>-<pid>`) when the record omits it.
- `loopCount`/`phase1Retries`/`phase2Retries` default from env vars
  `SPEC_LOOP_COUNT` / `SPEC_PHASE1_RETRIES` / `SPEC_PHASE2_RETRIES` when the
  record omits them (or entirely), defaulting to `0` — this is how the
  orchestrator injects spec 008's budget tracking into the record without the
  Verifier needing to read env vars itself.
- Exits 0 after a successful append. Never touches the file on validation failure.

Scenarios: `20-acceptance/AC-012-05-record-gate-run.md`

### Task 6 — Verifier appends one record per completed run

Wire the append into the pipeline: the Verifier records every completed run, and
the orchestrator supplies loop/retry context.

Acceptance criteria:
- `agents/spec-verifier.md` gains a "Telemetry" step: after its checks complete,
  the Verifier appends one record to `runs.jsonl` via
  `scripts/record-gate-run.sh` (bash-invoked; **no `permission.edit` change is
  needed** — the append happens through the helper's bash execution, preserving
  the "verifier writes nothing but the report + scratch" rule). Record fields are
  filled from its own run: `gatesFailed` = checks that FAILed or BLOCKed (gate
  IDs above), `warnings` = WARN findings (design-principles WARNs, spot-check
  notes), `durationSec` = wall-clock time of its verification phase,
  `outcome` = block/fail/pass per the precedence in Task 5, `specSlug` from the
  `specs/NNN-slug` directory it is verifying. `runId` is left to the script.
  The step runs even when the verdict is FAIL or BLOCK (every completed run is
  recorded), and its own failure is reported as a warning in the record/write-up,
  never a reason to fabricate a record.
- `agents/spec-pipeline.md` (orchestrator) exports `SPEC_LOOP_COUNT`,
  `SPEC_PHASE1_RETRIES`, `SPEC_PHASE2_RETRIES` before delegating to the Verifier,
  sourced from its loop/retry tracking per spec 008, so the record carries the
  budget audit trail (008 AC-004). If the orchestrator has no tracked counts it
  exports nothing and the defaults (0) apply.

Scenarios: `20-acceptance/AC-012-06-verifier-appends.md`

### Task 7 — `scripts/gate-stats.sh`: failure/retry rates from runs.jsonl

A model-free bash script that reads `runs.jsonl` and prints the drift signal.

Acceptance criteria:
- Usage: `gate-stats.sh [-f <file>] [-n <window>]`. Defaults: `runs.jsonl`,
  window 10. Parses the fixed schema with grep/sed/awk — no `jq`.
- Prints at minimum:
  - total runs; counts and percentage by `outcome` (pass/fail/block);
    failure rate = (fail + block) / total.
  - most-failed gate: the `gatesFailed` entry appearing in the most runs, with
    its count.
  - total warnings.
  - for `loopCount`, `phase1Retries`, `phase2Retries`: overall average and max,
    plus the average over the last `-n` runs.
  - creep detection: for each of the three retry metrics, compare the average over
    the last `-n` runs to the average over the `-n` before them; print both and
    mark `CREEP` when the recent average ≥ 1.5× the prior average and both ≥ 1.0.
- Missing/unreadable file → message to stderr, exit 1. Otherwise exit 0.

Scenarios: `20-acceptance/AC-012-07-gate-stats.md`

### Task 8 — Weekly gate-stats view

A scheduled workflow that runs `gate-stats.sh` so the drift signal surfaces
weekly without anyone running it by hand.

Acceptance criteria:
- `.github/workflows/gate-stats-weekly.yml`: `schedule` cron (Monday 06:00 UTC,
  e.g. `0 6 * * 1`) plus `workflow_dispatch` for on-demand runs; checks out the
  repo (which contains the committed `runs.jsonl`), runs
  `bash scripts/gate-stats.sh`, and uploads the report as a `gate-stats`
  artifact (stdout redirected to a report file for the artifact).
- `permissions: contents: read` — no write scope needed.

Scenarios: `20-acceptance/AC-012-08-weekly-stats.md`

## Acceptance criteria mapping

| Informal AC | Task | Scenario file |
|---|---|---|
| AC-001 selftests exercise every gate, wired into self-ci | 1 + 2 + 3 | `AC-012-01-principles-selftest.md`, `AC-012-02-traceability-selftest.md`, `AC-012-03-selfci-wiring.md` |
| AC-002 gate scripts accept `-ReportPath` for telemetry output | 4 | `AC-012-04-report-path.md` |
| AC-003 verifier appends a runs.jsonl record per completed run | 5 + 6 | `AC-012-05-record-gate-run.md`, `AC-012-06-verifier-appends.md` |
| AC-004 `gate-stats.sh` prints failure/retry rates | 7 + 8 | `AC-012-07-gate-stats.md`, `AC-012-08-weekly-stats.md` |

## Open questions (need a human answer before /build)

1. **Flag-style split across the batch.** 007's flags are double-dash
   (`--gates`, `--json`, `--checks`); 011's and 012's are single-dash
   (`-BaseRef`, `-ReportPath`). The current parser rejects `-*` outright, so both
   011 and 012 must extend it, and the two styles must coexist. Recommend one
   parser that accepts both forms (e.g. strip a leading `-` and match on the name)
   so reviewers don't get two incompatible parsers. Confirm the batch accepts
   this reconciliation, or name a single canonical style.
2. **Ordering dependency on 007.** The principles selftest relies on `--gates`
   for fixture isolation. If 012 lands before 007, the selftest fails fast with a
   clear message (by design) but self-ci would go red. Recommend landing the
   007/011/012 batch together (007 is already formalized); confirm that's the
   merge order.
3. **`-BaseRef` is 011's flag, not 012's.** The informal AC-002 lists
   "`-ReportPath`/`-BaseRef`", but `-BaseRef` (blame scoping) is spec 011's
   scope. 012 adds only `-ReportPath`. Confirm you agree the split is what the
   informal intended.
4. **`check-scenario-traceability.sh` lacks the +x bit** today (only
   `check-code-principles.sh` is executable). The selftest invokes it via `bash`
   so it works either way. Optional cleanup: give it +x in this spec's PR so the
   shellcheck `scripts/*.sh` step and direct invocation behave uniformly. Decide
   whether to include that as a drive-by fix or leave it.
5. **Child-repo propagation.** `runs.jsonl` lives per repo (repo root, committed)
   and the verifier appends in whichever repo runs the pipeline. For child repos,
   nothing in `init-ci.sh`/`init-deploy.sh` copies the selftests or the stats
   workflow. Out of scope here unless you want a follow-up to wire the selftests
   into child-repo CI templates via `init-ci.sh`.
