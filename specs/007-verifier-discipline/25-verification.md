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
