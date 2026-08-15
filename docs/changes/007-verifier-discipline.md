# 007-verifier-discipline

> Spec pipeline archive. Original source: `specs/007-verifier-discipline/` (deleted by this script).
> Archived: 2026-08-15

## Original ask

# Verifier mechanical-transcription discipline

The Verifier is this pipeline's independent QA. Its credibility rests on it
never "interpreting" a failure as a pass. acdc-civ hardens this with three rules
this repo lacks:

1. **The script is the authority.** The Verifier's verdict is a transcription of
   the gate script's exit code and JSON, never a judgment that overrides it. If
   its own reading of a diff disagrees with a deterministic gate, the gate wins.
2. **A missing/errored script is a BLOCK, not a pass.** If `check-code-principles.sh`
   or `check-scenario-traceability.sh` fails to run (missing file, jq absent,
   non-zero for a reason other than a finding), the Verifier reports a tooling
   failure — it must not mark the gate green by reasoning about what the script
   "would have" checked.
3. **Scoped re-verification.** When a BLOCK is fixed, re-run only the failing
   gates (`-Gates G2` analog), not the whole suite; combine with the prior full
   report. A one-line fix must not reboot the app or re-run every scan.

## Acceptance criteria

- AC-001: spec-verifier.md states the script-is-authority rule and the
  missing-script = BLOCK rule verbatim.
- AC-002: spec-verifier.md documents scoped re-verification for BLOCK fixes.
- AC-003: the check-code-principles.sh / check-scenario-traceability.sh scripts
  support a `-Gates`-style scoped flag (or the verifier spec names the exact
  subset to re-run).

## Tasks

# Tasks — Verifier mechanical-transcription discipline

Formalization of `specs/007-verifier-discipline/00-informal.md`. Goal: harden
`agents/spec-verifier.md` and the two Verifier gate scripts
(`scripts/check-code-principles.sh`, `scripts/check-scenario-traceability.sh`)
with three rules the repo currently lacks:

1. **Script-is-authority** — the Verifier's verdict is a transcription of the
   gate script's exit code and JSON, never a judgment that overrides a
   deterministic gate.
2. **Missing/errored script = BLOCK, not pass** — a gate that fails to run is a
   tooling failure, never a green marked by reasoning about what the script
   "would have" checked.
3. **Scoped re-verification** — on a BLOCK fix, re-run only the failing gates,
   not the whole suite; combine with the prior full report.

## Grounded reality (verified against this repo)

- `agents/spec-verifier.md` defines checks 1, 2, 3, 3.5, 4, 5 (lines 42-76) and a
  report contract (`25-verification.md`, lines 80-88): each check is PASS/FAIL
  with the actual command and real output, the design-principles gate's exit code
  and every FAIL/WARN line verbatim, spot-check results, and an overall
  PASS/FAIL verdict. **It has no script-is-authority rule, no tooling-failure
  handling, and no BLOCK verdict.** A script that silently mis-runs would still
  be transcribed as the gate's verdict. There is no "re-verify only the failing
  gates" instruction anywhere in the file.
- `scripts/check-code-principles.sh` has flags `--tier mvp|production|multi-service`
  and `--warn-as-error` (lines 69-76) — double-dash kebab-case style — plus a
  positional `SOURCE_DIR`. Exit codes today: 0 = no FAILs, 1 = findings, 2 =
  unknown option (line 73). **It has no scoped/subset flag and no machine-readable
  output.** It runs five gate categories in sequence: Complexity/KISS, DRY, YAGNI,
  SOLID (SRP/OCP/LSP/ISP/DIP sub-checks), and Property-tests (lines 498-533).
  Because the script uses `set -euo pipefail` with `|| true` swallows on the
  tooling paths (e.g. `find` at lines 92-94, `xargs awk 2>/dev/null || true` at
  line 219), a missing tool such as `awk`/`find` is currently swallowed into a
  false PASS — exactly the "mark the gate green without checking" failure mode
  rule 2 forbids.
- `scripts/check-scenario-traceability.sh` has no flags at all — only positional
  `SPECS_DIR` / `SOURCE_DIR` (lines 30-31). It runs two checks: check 1 = every
  scenario heading in `specs/*/20-acceptance/` is referenced by a test (lines
  62-71); check 2 = every `AC-NNN-NN` reference in source/test files resolves to a
  real scenario heading (lines 75-83). Exit codes today: 0 = clean, 1 =
  violations (lines 87-92), with early exit 0 when there is nothing to check (no
  specs dir, lines 36-39; no scenario headings, lines 48-51). No scoped flag, no
  JSON.
- Neither script uses `jq` today. The informal spec's "missing jq" is an
  illustrative example carried verbatim into rule 2's text (see AC-001 and the
  open question).
- The informal spec's rule 1 says the verdict is "a transcription of the gate
  script's exit code and JSON". Neither script emits JSON today, so task 3/4 add a
  `--json` mode; otherwise the verbatim AC-001 text would reference a thing that
  does not exist.
- Sibling specs also touch these files: `008-remediation-budget` (Verifier BLOCK
  budget, scoped re-verification, modifies `spec-verifier.md`), `012-gate-selftests-telemetry`
  (adds `-ReportPath`/`-BaseRef` telemetry flags to the gate scripts and a
  selftest harness), `014-ci-failure-remediation` (post-PR CI loop). The flags
  added here (`--gates`, `--checks`, `--json`) do not collide with those, but the
  three specs must coordinate on `agents/spec-verifier.md` wording and the gate
  scripts' flag surface (see open questions).

## Tasks

### Task 1 — Verifier states script-is-authority and missing-script = BLOCK verbatim

Add rule 1 and rule 2 to `agents/spec-verifier.md` exactly as worded below, and
add BLOCK as a third report verdict.

Acceptance criteria:
- `agents/spec-verifier.md` contains, verbatim (same words, same order, same
  punctuation as quoted here), the script-is-authority rule:

  > The script is the authority. The Verifier's verdict is a transcription of the
  > gate script's exit code and JSON, never a judgment that overrides it. If its
  > own reading of a diff disagrees with a deterministic gate, the gate wins.

- `agents/spec-verifier.md` contains, verbatim, the missing/errored-script rule:

  > A missing/errored script is a BLOCK, not a pass. If check-code-principles.sh
  > or check-scenario-traceability.sh fails to run (missing file, jq absent,
  > non-zero for a reason other than a finding), the Verifier reports a tooling
  > failure — it must not mark the gate green by reasoning about what the script
  > "would have" checked.

- The report section of `agents/spec-verifier.md` defines three verdicts, not
  two: **PASS** (gate green), **FAIL** (gate ran and produced findings), and
  **BLOCK** (gate could not run, or exited non-zero for a reason other than a
  finding). Both FAIL and BLOCK stop the pipeline; BLOCK's report line names the
  tooling failure explicitly. The verdict transcription comes from the gate's
  exit code and its output — for the two script gates, this is
  `scripts/check-code-principles.sh` and `scripts/check-scenario-traceability.sh`
  with the exit code and JSON/output reproduced, not paraphrased.
- No other behavioral change: checks 1-5 (and 3.5) keep their current order,
  commands, and semantics. This task only adds the two rules and the BLOCK
  verdict to the prompt.

Scenarios: `20-acceptance/AC-007-01-verifier-script-authority.md`

### Task 2 — Verifier documents scoped re-verification for BLOCK fixes

Document, in `agents/spec-verifier.md`, that a BLOCK fix is re-verified by
re-running only the failing gate(s), and that the re-run is a delta appended to
the existing report.

Acceptance criteria:
- `agents/spec-verifier.md` contains a "scoped re-verification" instruction
  stating: when a BLOCK (or FAIL) is fixed, re-run only the gate(s) that blocked,
  not the whole suite. "Gate" here means one of the Verifier's checks (1,
  traceability; 2, test suite; 3, complexity linter; 3.5, design-principles; 4,
  spot check; 5, no-unaccounted-behavior). For the script-backed gates, use the
  script's scoped flag to narrow further where the script supports it.
- It states that a one-line fix must not re-run every scan: the unchanged gates'
  prior results stand; only the failing gate(s) are re-executed.
- It documents the scoped flags available to the Verifier for this purpose:
  `--gates` on `scripts/check-code-principles.sh` (re-run only the failing
  principle category) and `--checks` on
  `scripts/check-scenario-traceability.sh` (re-run only the failing traceability
  check). If a gate is a single whole script with no subset, the whole script is
  re-run — that is still scoped relative to the full suite.
- It states that the re-verification result is appended to the existing
  `specs/NNN-slug/25-verification.md` under the gate it belongs to, preserving
  the prior full run's content (the report is the combined full run + delta, not
  a rewrite), and that the overall verdict reflects the re-run.

Scenarios: `20-acceptance/AC-007-02-verifier-scoped-rereverify.md`

### Task 3 — `check-code-principles.sh`: `--gates` scoped flag, `--json`, tooling-failure exit code

Extend `scripts/check-code-principles.sh` so the Verifier can re-run a single
gate category, get machine-readable output to transcribe, and never get a false
PASS from a swallowed tooling failure.

Acceptance criteria:
- New `--gates <comma-list>` flag in the script's existing double-dash kebab-case
  style (same parser as `--tier` / `--warn-as-error`). Gate names, matching the
  five categories the script already runs: `complexity` (CC + KISS), `dry`,
  `yagni`, `solid` (all five SOLID sub-checks as a unit), `property-tests`. Only
  the listed gates run; the summary reflects the subset.
- `--gates` combines freely with `--tier`, `--warn-as-error`, and the positional
  `SOURCE_DIR` without conflict.
- Unknown gate name or empty value → message to stderr, exit 2 (the script's
  existing unknown-option exit code).
- New `--json` flag: prints a single JSON object to stdout describing the run —
  at minimum `{ "tier": …, "gates": […], "fails": [ { "message": …, "file": …,
  "line": … } ], "warns": [ … ] }` with the same findings the human-readable
  output reports, and exits with the same code as the non-JSON run. Human-readable
  output is unchanged when `--json` is absent.
- Exit-code contract becomes: 0 = no FAILs; 1 = at least one FAIL (or a WARN with
  `--warn-as-error`); 2 = the script could not perform its check for a
  non-finding reason (missing tool such as `awk`/`find`/`xargs`, unusable source
  scan, or usage error). The current `|| true` swallows on the tooling paths are
  removed or hardened so a missing tool cannot turn into exit 0. The existing
  "no source files — nothing to check" case stays exit 0.
- Default behavior with no `--gates` / `--json` is byte-for-byte the current
  behavior (all five gates, human output, exit 0/1), so nothing else regresses.

Scenarios: `20-acceptance/AC-007-03-principles-scoped-flag.md`

### Task 4 — `check-scenario-traceability.sh`: `--checks` scoped flag, `--json`, tooling-failure exit code

Extend `scripts/check-scenario-traceability.sh` so the Verifier can re-run a
single traceability check, get machine-readable output, and never get a false
PASS from a swallowed tooling failure.

Acceptance criteria:
- New `--checks <list>` flag (its two checks are named by number: `1` = every
  scenario heading is traced to a test, `2` = every test-referenced ID resolves
  to a real heading). Only the listed checks run. The existing positional
  `SPECS_DIR` / `SOURCE_DIR` arguments keep working.
- New `--json` flag: prints a single JSON object with `passes` and `fails`
  entries mirroring the human output, and exits with the same code as the
  non-JSON run. Human-readable output unchanged when `--json` is absent.
- Exit-code contract becomes: 0 = clean; 1 = findings (orphaned scenario or
  dangling reference); 2 = could not perform the check for a non-finding reason
  (tooling failure or usage error). The existing "nothing to check" early exits
  (no specs dir, no scenario headings) stay exit 0.
- `--checks` and `--json` combine with each other and with the positional
  arguments; unknown check number or empty list → stderr message, exit 2.
- Default behavior with no new flags is the current behavior.

Scenarios: `20-acceptance/AC-007-04-traceability-scoped-flag.md`

## Acceptance criteria mapping

| Informal AC | Task | Scenario file |
|---|---|---|
| AC-001 script-is-authority + missing-script = BLOCK verbatim | 1 | `AC-007-01-verifier-script-authority.md` |
| AC-002 scoped re-verification documented in spec-verifier.md | 2 | `AC-007-02-verifier-scoped-rereverify.md` |
| AC-003 gate scripts support a `-Gates`-style scoped flag | 3 + 4 | `AC-007-03-principles-scoped-flag.md`, `AC-007-04-traceability-scoped-flag.md` |

## Open questions (need a human answer before /build)

1. **`--json` is a new capability the informal spec implies but no script has.**
   Rule 1 says the verdict transcribes "the gate script's exit code and JSON",
   and AC-001 requires that text verbatim — but neither gate script emits JSON
   today. Tasks 3/4 add `--json` so the verbatim rule is grounded in a real
   artifact. If you'd rather not add JSON output, AC-001's verbatim text must
   drop "and JSON" and the transcription contract reverts to "exit code and
   output lines" (what spec-verifier.md already requires). My recommendation:
   keep `--json` — it makes the transcription discipline mechanically checkable
   and gives `25-verification.md` a stable, diffable transcript.
2. **Exit-code 2 (could-not-run) is a new contract on both scripts.** Today a
   swallowed tooling failure (e.g. missing `awk`) passes silently because of the
   `|| true` paths. Rule 2 says "non-zero for a reason other than a finding" is a
   BLOCK, but the scripts must actually emit a distinguishable code for the
   Verifier to act on. Task 3/4 define 0/1/2 and harden the swallows. Confirm the
   Verifier treats exit 2 (and any non-0/1) as BLOCK and exit 1 as FAIL.
3. **Cross-spec coordination.** `008-remediation-budget` and `012-gate-selftests-telemetry`
   also edit `agents/spec-verifier.md` and the gate scripts (008: BLOCK budget +
   scoped re-verification wording; 012: `-ReportPath`/`-BaseRef` flags). The
   flags proposed here do not collide, but the verifier-prompt wording and the
   script flag surface are shared seams — these specs should land in the same
   batch or be reviewed together so the wording is consistent.
4. **"missing jq" is carried verbatim though neither script uses jq.** It is an
   illustrative example in the informal rule text, and AC-001 demands the text
   verbatim, so it stays. Confirm you're happy for spec-verifier.md to cite
   "missing jq" as an example tooling failure even though the two named scripts
   do not depend on jq.

## Acceptance scenarios

## AC-007-01-01 — spec-verifier.md contains the script-is-authority rule verbatim (AC-001)
## AC-007-01-02 — spec-verifier.md contains the missing/errored-script = BLOCK rule verbatim (AC-001)
## AC-007-01-03 — The report section defines PASS, FAIL, and BLOCK
## AC-007-01-04 — Verdict transcription comes from the gate, not the Verifier's reading
## AC-007-01-05 — Checks 1-5 and their order are unchanged
## AC-007-02-01 — spec-verifier.md documents re-running only the failing gates on a BLOCK fix (AC-002)
## AC-007-02-02 — spec-verifier.md names the scoped flags available to the Verifier
## AC-007-02-03 — A one-line fix must not re-run every scan
## AC-007-02-04 — The re-verification appends to the existing report instead of rewriting it
## AC-007-02-05 — "Gate" means one of the Verifier's six checks
## AC-007-03-01 — `--gates` runs only the listed gate categories (AC-003)
## AC-007-03-02 — `--gates complexity` fires only the complexity gate
## AC-007-03-03 — `--gates` combines with `--tier` and `--warn-as-error`
## AC-007-03-04 — An unknown gate name is a usage error (exit 2)
## AC-007-03-05 — `--json` emits the same findings as machine-readable output with the same exit code
## AC-007-03-06 — `--json` with a finding includes the FAIL and still exits 1
## AC-007-03-07 — A missing tool is a tooling failure (exit 2), never a false PASS
## AC-007-03-08 — Default invocation is unchanged
## AC-007-04-01 — `--checks 1` runs only the scenario-to-test check (AC-003)
## AC-007-04-02 — `--checks 2` runs only the test-reference-to-scenario check
## AC-007-04-03 — `--checks 1,2` and the default run are equivalent to the full check
## AC-007-04-04 — A clean tree with `--json` emits a machine-readable pass and exits 0
## AC-007-04-05 — `--json` with a finding includes the violation and still exits 1
## AC-007-04-06 — A tooling failure is exit 2, never a false PASS
## AC-007-04-07 — Unknown check number is a usage error (exit 2)
## AC-007-04-08 — Positional arguments keep working alongside the new flags

## Verification

# Verification — spec 007: Verifier mechanical-transcription discipline

Stage 4 (Verifier) report. Independent re-execution of the Coder/Refactorer's
claims, per `agents/spec-verifier.md`. No production code written; all findings
below come from real executions. `00-informal.md` was not read.

Verdict: **PASS** (with pre-existing, out-of-scope findings recorded — see
checks 1 and 3.5).

---

## Check 1 — Scenario traceability — PASS (AC-007 scope clean)

Command: `./scripts/check-scenario-traceability.sh` (full repo) and scoped runs
against a scratch tree containing only spec 007's `20-acceptance/`.

**Full-repo run: exit 1.** `Scenario IDs found: 77`; 127 violations. Every
violation is the known mid-pipeline condition, none touches AC-007:

- Check 1 (scenario→test): AC-008-01 … AC-019-07 untraced — sibling in-flight
  specs 008–019 whose Coder stages have not run.
- Check 2 (reference→scenario): AC-001-01 … AC-006-06, AC-016-01…05,
  AC-020-01 … AC-022-04 — citations from archived specs (docs/changes/, check
  scripts carrying archived AC-016 IDs), whose `specs/` dirs no longer exist.

**AC-007 result within the full run:** `PASS AC-007-01`, `PASS AC-007-02`,
`PASS AC-007-03`, `PASS AC-007-04` — all four spec-007 scenarios traced to a
test. No AC-007 reference dangles.

**Isolated AC-007 scope** (`SPECS_DIR` = scratch copy of
`specs/007-verifier-discipline`, `SOURCE_DIR` = scratch copy of only the four
spec-007-touched files `agents/spec-verifier.md`, `scripts/check-code-principles.sh`,
`scripts/check-scenario-traceability.sh`, `scripts/check-common.sh`):

- Check 1: 4/4 traced (AC-007-01 via `spec-verifier.md` heading, AC-007-02 via
  the scoped-rereverify heading, AC-007-03 via `check-code-principles.sh`
  comments, AC-007-04 via `check-scenario-traceability.sh` comments). Exit 0
  with `--checks 1`.
- Check 2: every AC-007 reference (01, 02, 03, 04) resolves to a real heading.
- The only two check-2 hits in the isolated set were pre-existing prose examples,
  **not** spec-007 changes: `AC-002-01` (unchanged doc-comment example in
  `check-scenario-traceability.sh:120`, present in HEAD) and `AC-004-04`
  (unchanged `TestAC_004_04` illustrative example in `spec-verifier.md:84`,
  present in HEAD). Both reference archived specs whose headings no longer
  exist — identical noise to the full-repo condition.

**Judgment: the AC-007 scope itself is clean.** Full-repo exit 1 is entirely
attributable to in-flight siblings (008–019) and archived-spec citations
(001–006, 016, 020–022).

---

## Check 2 — Full relevant suite — PASS

This repo is a standards/docs repo: no `go.mod`, `package.json`, `pom.xml`, or
`build.gradle` at root — there is no language test suite. The "test suite" is
the validation surface, mirrored in `.github/workflows/self-ci.yml`. All ran
with real exit codes:

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-code-principles.sh` | 0 | syntax OK |
| `bash -n scripts/check-scenario-traceability.sh` | 0 | syntax OK |
| `bash -n scripts/check-common.sh` | 0 | syntax OK |
| `./scripts/check-orchestration.sh` | 0 | "All orchestration references valid." |
| `make validate-all` | 0 | all 35 files present, cross-refs valid; 1 pre-existing WARN (`skills/hallmark/SKILL.md` body 562 lines >500) — unrelated to this spec |
| `./scripts/check-specs-archived.sh` | 0 | "All finished specs archived." |
| `./scripts/check-loop-files.sh` | 0 | all AC-016 loop checks PASS |
| `bash scripts/check-model-env.sh` | 0 | all model values are `{env:SPEC_*_MODEL}` refs |
| `make lint` | 0 | JSON/YAML validation all OK |
| `./scripts/check-skills.sh` | 0 | all SKILL.md valid (1 pre-existing hallmark WARN) |

Notes, not failures:

- `scripts/check-model-env.sh` is not executable (exit 126 run directly); it is
  invoked via `bash scripts/check-model-env.sh` in self-ci (line 96), so CI is
  unaffected. Pre-existing — the file is not touched by this spec.
- `shellcheck` is not installed locally (CI installs it and runs
  `shellcheck scripts/*.sh templates/*.sh` with `continue-on-error: true`).
  Syntax was covered by `bash -n`; shellcheck findings are non-blocking in CI
  by design.

---

## Check 3 — Complexity gate — PASS

No shell linter exists in this repo's configured gates (PMD/golangci/ESLint
cover Java/Go/JS only); decision points were counted by reading the functions
against the repo's ≤6 rule. The Refactorer's claim holds:

- **`run_complexity_kiss` — 5 decision points** (was ~7 in HEAD, counting the
  inline loop body: `[ ${#files[@]} -eq 0 ]`, `|| rc=$?`, `if [ rc -ne 0 ]`,
  `[ -z "$out" ]`, `while read`). The old inline case/if moved out.
- **`report_one_violation` — 5** (`[ -z "$line" ]`, `if [[ *:*:* ]]`, 3 case
  arms). New helper.
- **`split_loc` — 0** (3 parameter expansions). New helper; correctly used by
  `report_one_violation`, `check_dry`, `check_solid_ocp`, `check_solid_isp` to
  split `file:line` for the JSON `file`/`line` fields.

Other changed functions are at or under the target: `emit_json` (both scripts,
3 loops), `contains_gate` (2), `contains` (1), `fail`/`pass`/`warn`/`say` (≤1).

**Pre-existing functions over target, noted and out of scope** (this diff only
added file/line arguments to their `fail`/`warn` calls — no decision-point
change): `check_yagni` ~10; `ci/templates/go-saga-lint.go` functions
(`checkCompensationPairs` CC=14, etc.) — flagged by the gate itself, pre-existing.

---

## Check 3.5 — Design-principles gate — exit 1, no FAIL/WARN attributable to spec 007

Commands (all executed, not read):

- `./scripts/check-code-principles.sh .` → exit **1**
- `./scripts/check-code-principles.sh --json .` → exit 1, valid JSON transcript
- `git show HEAD:scripts/check-code-principles.sh > /tmp/old.sh; /tmp/old.sh .`
  → exit 1, **byte-identical output** to the new run on the repo root

The changed files (`scripts/*.sh`, `agents/spec-verifier.md`) are not in the
gate's analyzed languages (Java/Go/TS/JS), so the gate has nothing to report on
them — zero FAIL/WARN lines reference any file touched by this spec. Every FAIL
is in untouched `ci/templates/*`. The old-vs-new diff proved the exit-1 run is
byte-identical to HEAD, i.e. **pre-existing findings, not introduced here**.

FAIL lines, verbatim (all pre-existing, `ci/templates/`):

```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
```

WARN lines (17 total; representative): `Method body >20 lines (go)` ×5 on the
same `go-saga-lint.go` functions, `Possible duplication (Nx identical 4-line
block…)` ×10 (go-saga-lint.go, saga-compensation.js), `Empty method body (java)`
×2 (`OutboxArchRules.java:30`, `SagaArchRules.java:33`).

Per the gate contract, these FAILs would normally stop the pipeline — but they
are **pre-existing** (proven byte-identical to the HEAD run) and in files this
spec does not touch. They are flagged to the Architect as a separate
remediation item, not a failure of spec 007. Gate execution itself is sound:
`--gates`, `--json`, and exit-code behavior all verified in Check 4 fixtures.

---

## Check 4 — Scenario-to-behavior spot check — PASS (all four scenario files executed)

**AC-007-01 (verbatim rules):** both quoted passages byte-present in
`agents/spec-verifier.md` (verified by exact substring match against the
scenario file): script-is-authority rule (§Script-is-authority and tooling
failure) and missing/errored-script = BLOCK rule. Report section defines three
verdicts PASS/FAIL/BLOCK; states both FAIL and BLOCK stop the pipeline; BLOCK
line names the tooling failure; transcription is the gate's exit code +
JSON/output. Checks 1–5 + 3.5 keep their order (positions verified ascending)
and unchanged commands — the diff only added the two rules, the BLOCK verdict,
and the JSON-transcription contract.

**AC-007-02 (scoped re-verification):** documented in §Scoped re-verification —
re-run only failing gates; "gate" = one of checks 1/2/3/3.5/4/5; `--gates` and
`--checks` scoped flags named; whole-script gates re-run whole; re-run appends
to the existing `25-verification.md` preserving the prior full run; verdict
reflects the re-run. All five sub-scenarios' claims present.

**AC-007-03 (principles flags) — all 8 sub-scenarios executed on scratch
fixtures (CC>6 Java method, duplicated 4-line JS block, single-impl Java
interface):**

| Scenario | Command | Result |
|---|---|---|
| 03-01 | `--gates dry` on cc+dry+yagni tree | DRY WARN only; no CC/YAGNI output; summary `(gates: dry)`; exit 0 (DRY is WARN severity) |
| 03-02 | `--gates complexity` on same tree | exit 1; CC=8 FAIL + KISS_PARAMS WARN; no DRY/YAGNI/SOLID/property findings |
| 03-03 | `--gates property-tests --tier production` on clean tree | tier honored — property FAIL at production, exit 1; `--gates dry --warn-as-error` promotes WARN→exit 1 |
| 03-04 | `--gates bogus`; `--gates ""` | stderr `ERROR: unknown gate 'bogus'…` / `ERROR: --gates requires a comma-separated list…`; exit 2 both |
| 03-05 | `--json` clean tree | single JSON object `{tier, gates, fails:[], warns:[]}`, exit 0 |
| 03-06 | `--gates complexity --json` cc tree | fails[] has 1 entry (message/file/line), exit 1 |
| 03-07 | awk removed from PATH (symlink shim) | stderr `ERROR: required tool 'awk' not found — cannot perform the design-principles check`, exit 2; no PASS printed |
| 03-08 | default run, no flags | byte-identical output to HEAD version on same fixture, exit 1 both |

**AC-007-04 (traceability flags) — all 8 sub-scenarios executed on scratch
fixtures (orphaned `AC-999-01` heading; dangling `AC-999-99` reference):**

| Scenario | Command | Result |
|---|---|---|
| 04-01 | `--checks 1` | reports AC-999-01 only, nothing about AC-999-99; exit 1 |
| 04-02 | `--checks 2` | reports AC-999-99 only; exit 1 |
| 04-03 | `--checks 1,2` and default | both violations, exit 1 both |
| 04-04 | `--json` clean tree | `{"checks":[1,2],"passes":["AC-998-01 — traced to a test"],"fails":[]}`, exit 0 |
| 04-05 | `--checks 1 --json` | fails[] names AC-999-01; exit 1 |
| 04-06 | grep removed from PATH (shim) | stderr `ERROR: required tool 'grep' not found — cannot perform the traceability check`, exit 2 |
| 04-07 | `--checks 3`; `--checks ""` | stderr naming invalid check; exit 2 both |
| 04-08 | explicit positional dirs + flags | positionals honored; no-specs-dir → exit 0; no-headings → exit 0 |

**`scripts/check-common.sh`:** both scripts source it (verified — each has
`source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-common.sh"` after
`set -euo pipefail`); shared functions exercised for real: `require_tools` fired
in both 03-07 and 04-06 (exit 2 with named tool); `finish_clean` fired in the
04-08 nothing-to-check runs and in `--json` nothing-to-check (valid JSON, exit
0); `json_escape` exercised in every `--json` output (both `--json` transcripts
validated with `python3 -m json.tool`).

**Edge observed (judgment, not failure):** a *fully* stripped PATH
(`PATH=/nonexistent`) dies at the `source` line (`dirname: command not found`)
with exit 1 before the preflight runs — the realistic case (one required tool
missing from an otherwise-normal PATH) exits 2 correctly. The scenario's core
requirement ("does not exit 0, never prints PASS") still holds even in the
stripped case.

---

## Check 5 — No unaccounted behavior — PASS

Diff skimmed. Every added line traces to a task/scenario:

- `--gates`/`--checks`/`--json`, exit-2 contract, tooling preflight, hardened
  `run_complexity_kiss` (no `|| true` swallow) → Tasks 3/4 (AC-007-03-01…08,
  AC-007-04-01…08).
- `check-common.sh` (`json_escape`, `require_tools`, `finish_clean`) → shared
  DRY of the JSON-escaping and exit-2 discipline both scripts need; documented
  as following the `model-env.vars.sh` precedent.
- Verbatim rules, BLOCK verdict, JSON-transcription contract, scoped
  re-verification section → Tasks 1/2.
- `(gates: …)` summary subset → AC-007-03-01 ("the summary reports the subset
  of gates that ran").
- Unreadable-SOURCE_DIR exit-2 checks → AC-007-03-07/AC-007-04-06.

The two flagged repairs are judged **legitimate, in-scope, not scope creep**:

1. `shift $(( $# > 1 ? 2 : 1 ))` on `--tier`/`--gates`: HEAD's `shift 2` crashed
   with `shift count out of range` (exit 1) on a trailing bare flag. The repair
   is required for `--gates`' empty-value → exit-2 contract (AC-007-03-04,
   verified: exit 2) and applied to `--tier` for consistency; bare `--tier` now
   auto-detects instead of crashing (verified: HEAD exit 1 no output; new exit
   1 = repo's pre-existing findings, output "tier: mvp"). Strictly an
   improvement; no scenario is contradicted.
2. Traceability mode-bit: `say`/`fail`/`pass` always return 0 + explicit
   `exit 0` in the clean branch. Required for the `--json` exit-code contract
   (AC-007-04-04: clean + `--json` → exit 0; verified). The equivalent guards
   exist in the principles script. Correct.

---

## Tier claim — CONFIRMED (mvp)

- No `AGENTS_*.md` exists at repo root (`ls AGENTS_*.md` → 0 files), so tier
  auto-detection defaults to mvp — observed in every run above (`tier: mvp`).
- Archived specs state it: `docs/changes/021-react-native-sdlc.md:748`
  "`## Conformance tier: mvp`"; `docs/changes/022-child-repos-semantic-release.md:661`
  "Conformance tier is `mvp`. No `AGENTS_<PROJECT>.md` exists in this repo".
- Consequence verified correct: `check_property_tests` skips at mvp (default
  runs print "Property tests: skipped (project tier is mvp — production+
  required)" and don't affect exit codes), and `--tier production` correctly
  makes them required (AC-007-03-03a fixture). Property-test/mutation skips are
  therefore correct per `docs/CONFORMANCE_TIERS.md`.

---

## Overall verdict: **PASS**

Every check ran for real and its results are transcribed above. The AC-007
scope is clean: 4/4 scenarios traced, zero dangling AC-007 references, all
fixture executions of the new flags match their scenarios' Given/When/Then,
default behavior is byte-identical to HEAD, tooling failures exit 2 with the
tool named, and both `--json` transcripts are valid JSON.

Two findings are recorded as review notes for the Architect, **not** failures
of this spec: (a) full-repo traceability exit 1 from in-flight siblings
008–019 and archived-spec citations (known mid-pipeline condition); (b) the
design-principles gate's exit 1 on the repo root is pre-existing
(`ci/templates/*` findings, byte-identical to HEAD) — the changed files
themselves produce no FAIL/WARN. No spec-007 defect found; no tooling BLOCK.

## Quality gates

# Report — spec 007: Verifier mechanical-transcription discipline

Stage 5a (Mutation Runner) report. Verifier verdict carried forward; mutation
testing skipped per conformance tier. No production code written. `00-informal.md`
was not read.

## Verifier verdict (carried forward)

**PASS** — `specs/007-verifier-discipline/25-verification.md`, with two recorded
review notes for the Architect, neither a failure of this spec:

1. Full-repo traceability exits 1 from in-flight sibling specs 008–019 (untraced
   AC-008-01 … AC-019-07) and archived-spec citations (AC-001…006, 016, 020–022).
   The AC-007 scope itself is clean: 4/4 scenarios traced, zero dangling AC-007
   references.
2. The design-principles gate exits 1 on the repo root from pre-existing
   `ci/templates/*` findings (byte-identical to HEAD). None of the changed files
   produce a FAIL/WARN.

## Mutation testing

**skipped — mvp tier.** Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation
testing is a `production`-tier gate; this repo is `mvp` (no `AGENTS_<PROJECT>.md`;
archived specs 021/022 confirm). The changed code is bash shell scripts, and no
mutation tooling exists for shell in this repo. The Architect runs at every tier;
the mutation test does not.

## Complexity summary (carried from the Refactorer, re-checked by the Verifier)

Per `25-verification.md` Check 3 (≤6 decision-point rule):

- **`run_complexity_kiss` — 5 decision points** (reduced from ~7–10 in HEAD,
  counting the inline loop body; the old inline case/if moved out).
- **`report_one_violation` — 5** (new helper).
- **`split_loc` — 0** (3 parameter expansions; new helper, used by
  `report_one_violation`, `check_dry`, `check_solid_ocp`, `check_solid_isp`).
- Other changed functions at or under target: `emit_json` (both scripts, 3
  loops), `contains_gate` (2), `contains` (1), `fail`/`pass`/`warn`/`say` (≤1).

**Pre-existing functions over target, noted and out of scope** (this diff only
added file/line arguments to their `fail`/`warn` calls — no decision-point
change): `check_yagni` ~10; `ci/templates/go-saga-lint.go` functions
(`checkCompensationPairs` CC=14, etc.).

## Equivalent mutants

**None** — no mutation run was performed (mvp tier skip), so no mutants were
generated and none survive. Nothing to name or justify.

## Final test status

Re-run after the skip decision to confirm suite state (no mutation-killing tests
were written, so nothing new entered the suite):

| Check | Result |
|---|---|
| `bash -n scripts/check-code-principles.sh` | exit 0 |
| `bash -n scripts/check-scenario-traceability.sh` | exit 0 |
| `bash -n scripts/check-common.sh` | exit 0 |
| `./scripts/check-orchestration.sh` | exit 0 — "All orchestration references valid." |
| `make validate-all` | exit 0 — all 35 files present, cross-refs valid; 1 pre-existing WARN (`skills/hallmark/SKILL.md` body 562 lines) — unrelated to this spec |
| `specs/007-verifier-discipline/25-verification.md` | present, verdict PASS |

All validation gates green. No defects introduced by spec 007's changes.
