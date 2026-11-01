# 30-report — 037-split-spec-pipeline-doc

Mutation Runner: stage 5a (`spec-mutation-runner`). Ran only after stage 4
(`spec-verifier`) recorded a **PASS** verdict in `25-verification.md`.

- Worktree: `/home/dbueno/.local/share/opencode/worktree/471827/spec-037`
- Base commit: `39fdd21` (detached HEAD)
- Conformance tier: **`mvp`**
- Information barrier: `specs/*/00-informal.md` was **not** read. Mutation-kill
  reasoning and the final suite re-run use only the tests, `10-tasks.md`,
  `20-acceptance/`, and `25-verification.md`.
- Autopilot: false (no `45-decisions.md`; no autopilot decisions were required)

## Summary rows

| Item | Result |
|---|---|
| Verifier verdict (carried forward) | **PASS** — no gate failed; see §Verifier verdict |
| Mutation score | **skipped — `mvp` tier** (see §Mutation score) |
| Complexity summary (carried from Refactorer) | 0 FAIL; complexity gate and design-principles gate clean — see §Complexity summary |
| Equivalent mutants | **none to report** — no mutation run occurred, so no survivor set exists |
| Final test status | **GREEN** — 762 ok, 0 not ok, 0 skipped, `make test` exit 0 |
| Remediation record | **none** — no BLOCK occurred in phase 1 or phase 2 |

## Evidence: mutation score

command: scripts/check-code-principles.sh --json | grep -o '"tier": "[a-z]*"'; for t in gremlins go-mutesting stryker; do command -v "$t" || echo "$t: absent"; done; ls pom.xml package.json go.mod
exit: 0
at: 2026-11-01T13:40:20Z

```
"tier": "mvp"
gremlins: absent
go-mutesting: absent
stryker: absent
ls: cannot access 'pom.xml': No such file or directory
ls: cannot access 'package.json': No such file or directory
ls: cannot access 'go.mod': No such file or directory
mutation-config: none
```

**Mutation score: skipped — `mvp` tier.**

Per `docs/spec-pipeline/audit-contract.md §Conformance tiers` and
`docs/CONFORMANCE_TIERS.md` (`Mutation testing (PiTest / Gremlins / Stryker)` =
`production`), mutation testing is a `production`-tier gate. This project runs at
`mvp`: `scripts/check-code-principles.sh --json` reports `"tier": "mvp"`, and no
project file declares a higher tier (`## Conformance tier:` absent from
`AGENTS.md`), so the Stop-and-Ask matrix's "project type ambiguous" row resolves to
the harness default `mvp` — not a stop, a recorded default.

Two independent facts confirm the skip is not hiding runnable tooling:

1. **No language manifest to mutate.** This repo's own code is shell + markdown.
   `pom.xml`, `package.json`, and `go.mod` do not exist at the root, so there is no
   Java/JS/Go production surface for PiTest, Stryker, or Gremlins to attack.
   `ci/templates/mutation.mk` is a **template shipped to child repos** (its header:
   "copy into the project's Makefile"), not a target of this repo.
2. **No mutation binary is installed.** `gremlins`, `go-mutesting`, and `stryker`
   are all absent from `PATH`.

The spec's executable surface (`scripts/check-orchestration.sh` checks 4+6,
`scripts/measure-stage-read-cost.sh`) is already covered by assertion-bearing AC-037
tests that ran green — see §Final test status — which is the coverage benefit the
mutation gate exists to protect. That is a supporting observation, not a substitute
for the gate, and this report does not claim a score.

## Complexity summary (carried from the Refactorer)

The Refactorer leaves no report artifact (`docs/spec-pipeline/audit-contract.md
§What each stage leaves behind`); its gate measurements are re-recorded by the
Verifier and carried here. Source: `25-verification.md` §Evidence: complexity gate
and §Evidence: design-principles gate.

| Gate | Command (as run by the Verifier) | Exit | Result |
|---|---|---|---|
| Complexity gate | `make lint` + `shellcheck -S warning` on the two new/rewritten scripts + `bash -n` on every changed `.sh` | 0 | PASS — 57 `[OK]`, 0 `[FAIL]`; shellcheck no output; all files parse |
| Design-principles gate | `scripts/check-code-principles.sh --json` | 0 | PASS — **0 FAIL**; 58 WARN, all pre-existing |
| Design-principles, blame-scoped | `scripts/check-code-principles.sh --json -BaseRef HEAD` | 0 | PASS — **0 FAIL, 0 WARN** attributable to this diff |

Cyclomatic/complexity for this repo's code is measured by `shellcheck` plus the
design-principles `complexity` category (there is no golangci/PMD/ESLint surface for
shell). Both report zero findings for this diff. No threshold was changed; the gate
config was not touched by this stage.

## Final test status

Re-run from scratch **after** the mutation-clean determination (here: after the
`mvp` skip), because the Verifier's PASS predates this stage. No new test code was
written by this stage, so this run is a straight re-confirmation of stage 4's result
on the same tree.

## Evidence: final test status

command: make test
exit: 0
at: 2026-11-01T13:40:08Z

Started 2026-11-01T13:36:30Z, finished 2026-11-01T13:40:08Z (bats 1.11.0,
`bats --tap scripts/tests/*.bats`). Totals: **762 ok, 0 not ok, 0 skipped**.
Identical totals to the Verifier's run in `25-verification.md` — no regression was
introduced between stages 4 and 5a.

`scripts/check-bats-assertions.sh` (the anti-vacuity guard) ran first inside the
same target and passed: `PASS check-bats-assertions: 75 bats file(s), no vacuous
assertions.`

Every AC-037 scenario test ran and passed (verbatim TAP lines):

```
ok 198 AC-037-01-01: index keeps the cross-cutting sections
ok 199 AC-037-01-02: Stop-and-Ask table rows are byte-identical to the base commit
ok 200 AC-037-01-03: index length is at most 250 lines
ok 201 AC-037-01-04: every stage-file path in the Stage files table exists
ok 203 AC-037-04-01: the split tree passes check-orchestration
ok 204 AC-037-04-02: a missing docs/spec-pipeline path is reported and exits 1
ok 205 AC-037-04-03: a missing §anchor in a stage doc prints file:line and exits 1
ok 206 AC-037-04-04: an index §anchor that exists resolves and exits 0
ok 209 AC-037-05-01: every stage reads at most 50% and the script exits 0
ok 210 AC-037-05-02: a stage over the budget exits 1 and is named
ok 211 AC-037-05-03: a stage at exactly 50% of the baseline passes
ok 214 AC-037-03-01: moved-section references are repointed to the new file
ok 215 AC-037-03-02: index-section references keep the index path
ok 216 AC-037-03-03: each stage agent reads its own stage file plus named index sections
ok 219 AC-037-02-01: one file per stage agent under docs/spec-pipeline/
ok 220 AC-037-02-02: every original top-level section lands in exactly one file
ok 221 AC-037-02-03: named sections live in their owning stage file
ok 222 AC-037-02-04: every stage file points back to the index and names its index sections
```

Tail of the run (verbatim):

```
ok 758 unit: invalid --max-state-bytes values are usage errors (exit 2, no request)
ok 759 unit: invalid JUDGMENT_MAX_STATE_BYTES is a usage error (exit 2)
ok 760 unit: a cap smaller than the marker still never exceeds the cap
ok 761 unit: state exactly at the cap is not truncated and emits no reason
ok 762 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)
```

## Equivalent mutants

**None.** Equivalent-mutant analysis only exists relative to a mutation run's
survivor set; no run occurred at `mvp` tier, so there is no survivor set and nothing
to name as un-killable. This stage asserts no mutation cleanliness and does not claim
one — the honest statement is "not measured", with the tier as the reason.

## Verifier verdict (carried forward)

**PASS** — `25-verification.md`, attempt 1 / phase 1. Every gate ran and produced
no findings:

| Gate | ID | Exit | Result |
|---|---|---|---|
| Scenario traceability | `traceability` | 0 | PASS — AC-037-01..05 all traced |
| Full test suite | `test-suite` | 0 | PASS — 762 ok, 0 not ok, 0 skipped |
| Complexity gate | `complexity` | 0 | PASS |
| Design-principles gate | `design-principles` | 0 | PASS — 0 FAIL, 58 pre-existing WARN |
| Scenario-to-behavior spot check | `spot-check` | — | PASS — 3 scenarios, assertions match Given/When/Then |
| Orchestration wiring (supplementary) | `orchestration` | 0 | PASS |
| Read-cost (supplementary) | `read-cost` | 0 | PASS — worst stage `pr-opener` 0.480 |

Gate IDs failed: none. This stage independently re-confirmed the `test-suite` row
above; the other rows are carried forward, not re-run, and are attributed to stage 4.

## Remediation record

**none** — no BLOCK occurred during this run.

Carried forward, not guessed (`docs/spec-pipeline/audit-contract.md
§Remediation budget`):

- `25-verification.md` header records **attempt 1, phase 1**, "first full run, no
  prior BLOCK in this phase", with orchestrator counters `SPEC_LOOP_COUNT=1`,
  `SPEC_PHASE1_RETRIES=0`, `SPEC_PHASE2_RETRIES=0`.
- No BLOCK is recorded anywhere in `25-verification.md`, so there is no phase or
  attempt count to attribute. Phase 2 has not started: it begins after stage 5b
  pushes and opens the draft PR.
- `25-verification.md` §Telemetry records that those three counters were **not
  exported** into the Verifier's shell, so `record-gate-run.sh` wrote `loopCount: 0`
  by default. The authoritative counters for this run are the ones the orchestrator
  passed: **loop 1, phase-1 retries 0, phase-2 retries 0**. Neither file was
  rewritten (append-only contract), and no duplicate telemetry record was appended
  because it would double-count the run in `scripts/gate-stats.sh`.

Budget consumed by this stage: **0 of 3** phase-1 attempts (no gate failed), **0 of
3** phase-2 attempts (not started).

## WARNs and follow-ups carried forward

Recorded per the Stop-and-Ask matrix row "Design gate WARN (not FAIL) → record in
the report; do not stop; flag to the Architect". None was fixed by this stage — this
stage does not modify production code or gate thresholds.

### Out-of-scope findings (recorded, not fixed, follow-up spec proposed)

**O-1 — `check-agent-doc-duplication.sh` scans only the index after the split,
so `check-orchestration.sh` check 5 is silently weaker than before.**

The checker compares `agents/*.md` verbatim against a single path,
`DOC="$ROOT/docs/SPEC_PIPELINE.md"`; `check-orchestration.sh` check 5 delegates to
it. Before this spec the index held all 23 sections, so one path was full coverage.
After the split the index keeps 6 sections and 42,448 bytes of rules live in
`docs/spec-pipeline/*.md` — outside the scanner's reach. Not a gate failure for this
spec (Task 4 scoped the `check-orchestration.sh` extension to check 4 plus the new
anchor check, and no AC-037 scenario covers check 5), and not a live defect: run
against a scratch tree whose `docs/SPEC_PIPELINE.md` was the index plus every
`docs/spec-pipeline/*.md` concatenated, the checker exited 0 with
`OK: agents/*.md duplicate no docs/SPEC_PIPELINE.md rule and all section references resolve`
— zero actual duplication today. This is a **latent coverage regression, not a
current break**.

Classification: structural, out of scope, follow-up spec. Fix shape: the checker
should accept a doc **list** (index + `docs/spec-pipeline/*.md`) rather than one
path, and check 5 should pass the full list.

**O-2 — `tests/AC-030-01.sh` has a `printf | grep -q` SIGPIPE flake under
`pipefail` (pre-existing, spec 030's file, not this spec's).**

`set -euo pipefail` at line 4 with `printf '%s\n' "$fm" | grep -qE '^name:'` at line
12: `grep -q` exits on first match, `printf` takes SIGPIPE, `pipefail` propagates the
non-zero status, and the pipeline flakes as the payload grows or the scheduler
interleaves. The file's last change is `b320843` (spec 030) and it is absent from
this diff (`git status --porcelain tests/` empty), so this spec neither caused nor
worsened it. It did **not** reproduce in either run — the Verifier saw
`ok 18 AC-030-01-06: required body sections present`, and this stage's re-run saw
the same line pass (part of the 762 ok). Absence of a repro under load does not
retire the defect: it is timing-dependent, and a green run is not evidence the race
is gone.

Classification: behavior defect in a pre-existing test, out of scope, follow-up
spec. Fix shape: replace `| grep -q` with a `case`/`[[ =~ ]]` test, or drop
`pipefail` for that one statement. Note that this flake is the *exact* class of
failure a mutation-clean suite cannot detect — the mutation gate measures whether
tests assert, not whether they are race-free.

### WARNs from the Verifier (structural, live, this spec's surface)

**W-1 — `measure-stage-read-cost.sh` exits 2 correctly but prints a bash
arithmetic error on the way.** A missing **shared** file named in a `Must read:`
block reaches exit 2 (the documented contract) but only after `stage_bytes` runs
`bytes=$((bytes + $(size_of "$shared")))` with an empty substitution, emitting
`line 90: bytes + : syntax error: operand expected` and a partial results table
first. A missing **index** is clean (exit 2, bats-covered). Exit code is the
contract and the contract holds → WARN, not FAIL. Fix worth having: `stage_bytes`
should return non-zero on a failed `size_of` instead of relying on the arithmetic
error to abort.

**W-2 — "Do not read the other stages' files" collides with verifying a docs
spec.** AC-037-03-03 required each stage agent to read only its own slice, and all
eight `agents/spec-*.md` prompts now end their reading paragraph with *"Do not read
the other stages' files."* For a spec whose **deliverable is the other stage
files**, that instruction cannot be satisfied literally without blocking review of
the artifact. Recording the resolution used here: this stage read
`docs/SPEC_PIPELINE.md` (the index — its own stage file's allowed surface),
`25-verification.md`, `10-tasks.md`, and `20-acceptance/` only, and did **not** read
the other stage files or `00-informal.md`. No AC covers the collision, no gate
fails. Suggested follow-up: scope the prohibition to "when executing your stage",
not "ever".

**W-3 — comma-form references escape the new anchor check.** Four repointed
references use the wrapped prose form ``(`docs/spec-pipeline/x.md`, §Section)``
(index `§Remediation budget`, `audit-contract.md` lines 91 and 136, `pr-opener.md`
line 24). Check 6 requires `<path> §<section>` adjacency, so these are not
anchor-verified. All four were hand-verified by the Verifier to resolve, and the
base had the same unverified `§`-only form, so this is **not a regression** — but
the new gate's coverage of the docs it just created is incomplete. Recorded, not
fixed.

### Observations carried forward

**N-1 — two files outside Task 3's enumerated surface were edited.** `CHANGELOG.md`
and `okf/when-to-use-typesafe.md` are outside Task 3's `agents/ commands/ AGENTS.md
docs/ scripts/ skills/` list. Both are single-line reference repoints that remove a
reference which would otherwise have gone stale, with no change to the historical
statement's meaning. Justified in effect, unaccounted by the task list's letter.
Recorded so stage 5b's commit scope is visible, not assumed.

**N-2 — thin read-cost margin on `pr-opener`.** Worst stage is `pr-opener` at
0.480 (24,439 bytes = 96.1% of the 25,418-byte budget). Passing, but any growth of
`pr-opener.md` — or of a shared file it Must-reads — above ~979 bytes breaks the
≥50% claim. Worth a follow-up note for whoever next edits that file; not a gate
failure today.

**N-3 — move is verbatim.** All 23 base sections land exactly once, nine differ
only by the new index-intro paragraph or an explicit path on an otherwise-dangling
`§Section` reference, and the Stop-and-Ask table lines carry identical SHA-256
between base and current index. Zero semantic rewrites. Index length 228 ≤ 250.

## Handoff to stage 5b (PR Opener)

This report is **green**: Verifier PASS carried forward, mutation gate skipped for a
recorded `mvp`-tier reason, final suite green (762 ok / exit 0). Precondition for
stage 5b is satisfied.

This stage did **not** commit, stage, push, or open a PR, did not create a git tag,
and did not modify any gate threshold or gate config. The working tree still carries
the spec's uncommitted deliverable; committing it is stage 5b's job on branch
`spec/037-split-spec-pipeline-doc`.

`30-report.md` is the *finished* signal for this folder (it is what
`scripts/archive-spec.sh` and `scripts/check-specs-archived.sh` key off), so stage 5d
must archive this spec in the same PR before merge. Stage 5b should run
`scripts/check-audit-trail.sh 037-split-spec-pipeline-doc` before pushing.
