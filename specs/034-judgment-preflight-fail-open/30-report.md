# Report: 034-judgment-preflight-fail-open

Stage 5a (Mutation Runner) + structural report for spec 034. Scope of the change
set: `scripts/typed-judgment.sh`, `scripts/judgment-preflight.sh`,
`scripts/judgment-status.sh` (new), `scripts/judgment-lib.sh` (new), `Makefile`,
`agents/spec-pipeline.md`, `agents/spec-ux.md`, `skills/ci-triage/SKILL.md`,
`config/model.local.env.example`, `docs/SPEC_PIPELINE.md`, `docs/adr/README.md`,
`docs/adr/0012-judgment-consumer-contract-fail-open-preflight.md` (new),
`scripts/check-post-pr-ci-loop.sh`, `scripts/tests/*.bats`,
`scripts/tests/test_helper.bash`. No Go/Java/JS/Python/Rust source is touched.

## Verifier verdict (carried forward)

**PASS** — `specs/034-judgment-preflight-fail-open/25-verification.md`,
`Overall verdict: PASS`, `- Attempt: 1 (first full run), phase 1`. All five
contract checks carry evidence blocks with command, exit, UTC timestamp, and raw
output. Mutation testing was therefore correctly gated on that PASS before this
stage ran.

## Conformance tier and mutation-testing applicability

Tier: **`mvp`** (harness default — this repo declares no tier).

Evidence for the tier ruling:

```
command: grep -n "Conformance tier: production" AGENTS.md AGENTS_*.md
exit: 2
at: 2026-10-26T02:54:21Z

(no match — exit 2, no output: no `Conformance tier:` declaration exists in
AGENTS.md or any AGENTS_*.md, so per docs/SPEC_PIPELINE.md §Stop-and-Ask decision
matrix ("Project type ambiguous … defer to the harness default (`mvp` tier)") and
docs/CONFORMANCE_TIERS.md §How to declare a tier, the effective tier is `mvp`.)
```

Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is the
Architect row that `mvp` **skips**; the stage still runs (this report), the
mutation *gate* does not.

## Mutation score

```
command: make mutation
exit: 0
at: 2026-10-26T02:54:31Z

skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)
```

**Mutation score: skipped — `mvp` tier.** (`make mutation`'s own tier detection
is the same `grep "Conformance tier: production" AGENTS.md AGENTS_*.md` the
evidence above resolves, so the skip is the repo's own declared gate behavior,
not this agent's judgment call.)

### Compounding reason: no shell mutation lane exists

Independently of the tier, the change set is bash-only and this repo ships no
mutation runner for shell. Evidence:

```
command: command -v gremlins; command -v go-mutesting; command -v stryker; ls stryker.conf.json .strykerrc.json; ls pom.xml go.mod package.json
exit: gremlins=1, go-mutesting=1, stryker=1, stryker_conf=2, build_files=2
at: 2026-10-26T02:54:40Z

(no gremlins, no go-mutesting, no stryker on PATH; no stryker config; no pom.xml,
go.mod, or package.json at the repo root — none of the three mutation lanes in
docs/TESTING.md §Mutation Testing has a target in this repository at all.)
```

`docs/TESTING.md §Mutation Testing` enumerates exactly four lanes — Java
(`PiTest`, `mvn verify -Pmutation`), Go (`gremlins unleash`), JS/TS (`npx stryker
run`), React Native (Stryker/Jest) — and `docs/SPEC_PIPELINE.md §Tooling by
language` lists the same three-language set (Java / Go / JS-TS). Shell has no
entry in either table, so a `.sh`/`.bats` change set has no configured mutator
and no ≥80% score to report. Recorded skip with evidence, per the decision
matrix — not a blocked gate.

## Equivalent mutants

**None — no mutation run was performed**, therefore no surviving mutants exist
and no equivalent (un-killable) mutant can be named. This is not a claim that the
shell code is mutation-clean; it is a statement that no mutator executed against
it, so the concept does not apply to this run. If a bash mutation lane is adopted
later, the kill surface for these four scripts is the 524-test bats suite
(`scripts/tests/*.bats`), which is where such a lane's survivors would have to
be killed.

## Complexity summary (carried from the Refactorer, re-recorded by the Verifier)

The Refactorer leaves no artifact by design; its complexity/duplication/
property-test claims were re-executed by the Verifier and are re-run here.

```
command: scripts/check-code-principles.sh --gates complexity -BaseRef main --json
exit: 0
at: 2026-10-26T02:54:26Z

{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": []
}
```

- Cyclomatic ≤6 gate: **PASS**, zero FAIL, zero WARN, blame-scoped to the change
  set (`-BaseRef main`), matching the Verifier's own run
  (`2026-10-26T02:48:55Z`, identical JSON).
- Coverage caveat, stated so the PASS is not over-read: the gate's scanned
  extensions are `java, go, ts, tsx, js, jsx, py, rs`
  (`scripts/check-code-principles.sh` line ~400). **`.sh` is not among them**, so
  for this bash-only change set the gate passes vacuously — it does not measure
  the changed files. Recorded as a gate-scope limitation, not a defect in the
  change set.
- Supplementary measurement (not a gate, not blocking): the same decision-point
  heuristic the gate applies to other languages (`if`/`elif`/`for`/`while`/
  `case`/`&&`/`||`), counted per shell function across the four scripts —
  **max CC = 5** (`typed-judgment.sh:call_api`, `typed-judgment.sh:check_callable`),
  next highest 4 (`judgment-status.sh:main`), every other function ≤3. Under the
  ≤6 rule.
- Property tests: **skipped — `mvp` tier** (Refactorer property-test row is
  `production` and above; `make property-tests` prints the same tier skip).
- Duplication: no DRY FAIL/WARN in the scoped design-principles run (the
  duplicated probe/cap logic was extracted into `scripts/judgment-lib.sh`, which
  is what removed it).

## Gate results carried forward

| Gate | Result | Evidence |
|---|---|---|
| Verifier verdict | PASS | `25-verification.md` §Overall verdict (attempt 1, phase 1) |
| Scenario traceability | PASS — 33/33 AC-034 IDs traced, 0 fails | `25-verification.md` §Evidence: scenario traceability, exit 0 |
| Full test suite (Verifier, ×2) | PASS — 524 tests, 0 `not ok`, both runs | `25-verification.md` §Evidence: full test suite, exit 0 |
| Complexity gate | PASS — 0 FAIL / 0 WARN, scoped | `25-verification.md`, re-run above |
| Design-principles gate (scoped) | PASS — 0 FAIL / 0 WARN | `25-verification.md` §Evidence: design-principles gate, exit 0 |
| Design-principles gate (whole repo, unscoped) | FAIL ×1 — pre-existing, out of scope | see §Out-of-scope findings |
| Scenario-to-behavior spot check | PASS — 4 scenarios read against their assertions | `25-verification.md` |
| Mutation testing | SKIPPED — `mvp` tier (and no shell lane) | this report §Mutation score |
| Bash syntax (`bash -n`, 4 scripts) | PASS — `scripts/typed-judgment.sh`, `judgment-preflight.sh`, `judgment-status.sh`, `judgment-lib.sh` | run at 2026-10-26T02:54:2x Z, exit 0 |

ShellCheck: **not run — not installed on this machine** (`command -v shellcheck`
exits 1). No lint claim is made for the shell sources.

## Final test status (full suite, one final time)

Re-run after the mutation stage, because mutation-kill work would have been new
test code the Verifier never saw. No mutation-kill tests were added (no mutator
ran), so the suite is byte-for-byte the Verifier's suite — re-confirmed anyway.

```
command: make test-scripts
exit: 0
at: 2026-10-26T02:51:01Z

TAP plan: 1..524
ok    lines: 524
not ok lines: 0
run completed at: 2026-10-26T02:54:02Z

tail (last 5 lines, verbatim):
ok 520 unit: invalid --max-state-bytes values are usage errors (exit 2, no request)
ok 521 unit: invalid JUDGMENT_MAX_STATE_BYTES is a usage error (exit 2)
ok 522 unit: a cap smaller than the marker still never exceeds the cap
ok 523 unit: state exactly at the cap is not truncated and emits no reason
ok 524 unit: successful under-cap call writes no reason line at all
```

**Final test status: GREEN — exit 0, 524/524, 0 failures, 0 skipped.**

## Remediation record

**none** — no BLOCK occurred during the run.

- Carried forward from `25-verification.md`: `- Attempt: 1 (first full run),
  phase 1` and `Overall verdict: PASS`. The Verifier reached PASS on its first
  attempt, so no Phase 1 remediation cycle, no scoped re-verification, and no
  re-delegation to the Coder or Refactorer happened. No attempt count is
  consumed.
- Phase 2 (post-PR CI): not started — no PR exists yet (that is stage 5b). No
  entries to carry.
- Phase 3 (deploy verification): not started; non-frontend lane in any case.
- Orchestrator loop summary: no BLOCK entries were passed to this stage.
  Nothing is inferred or invented here.

## Out-of-scope findings (recorded, not fixed — decision-matrix `mvp` behavior)

1. Whole-repo design-principles run (`scripts/check-code-principles.sh --json`,
   exit 1) reports one pre-existing FAIL, unrelated to this change set:
   `./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10`. The file is
   not in `git diff` for this spec; the blame-scoped run is the verdict for the
   change set. Proposed follow-up: a small lint/complexity cleanup spec for
   `skills/hallmark/site/examples/`.
2. Verifier's flag (not a FAIL): `scripts/tests/typed-judgment*` assertion
   AC-029-74 hardcodes the spec-034 / ADR-0012 escape hatch, so the next spec
   that edits consumer files must amend it again. Proposed follow-up: generalize
   the assertion to "documented change = ADR present in the same change set".
3. Complexity-gate blind spot for `.sh` (see §Complexity summary). Proposed
   follow-up, only if shell keeps growing: extend
   `scripts/check-code-principles.sh` to a bash decision-point heuristic, with
   the ≤6 threshold unchanged (gate config is not something a pipeline agent
   changes).

## Pipeline gate (audit trail) — run before the final status below

```
command: scripts/check-audit-trail.sh 034-judgment-preflight-fail-open
exit: 0
at: 2026-10-26T02:54:57Z

PASS 034-judgment-preflight-fail-open: 10-tasks.md present and non-empty
PASS 034-judgment-preflight-fail-open: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 034-judgment-preflight-fail-open: 25-verification.md present and non-empty
PASS 034-judgment-preflight-fail-open: 30-report.md present and non-empty
PASS 034-judgment-preflight-fail-open: evidence block 'scenario traceability' — command: scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-10-26T02:38:12Z
PASS 034-judgment-preflight-fail-open: evidence block 'full test suite' — command: make test-scripts   (run twice, as required), exit: 0, at: 2026-10-26T02:38:38Z
PASS 034-judgment-preflight-fail-open: evidence block 'complexity gate' — command: scripts/check-code-principles.sh --gates complexity -BaseRef main --json, exit: 0, at: 2026-10-26T02:48:55Z
PASS 034-judgment-preflight-fail-open: evidence block 'design-principles gate' — command: scripts/check-code-principles.sh -BaseRef main --json, exit: 0, at: 2026-10-26T02:38:32Z
PASS 034-judgment-preflight-fail-open: evidence block 'scenario-to-behavior spot check' — command: manual inspection of agents/spec-ux.md, scripts/typed-judgment.sh, scripts/judgment-preflight.sh against AC-034-07, AC-034-13, AC-034-20, AC-034-21, exit: 0, at: 2026-10-26T02:48:55Z
✔ Audit-trail check: specs/034-judgment-preflight-fail-open complete, verifier evidence recorded.
```

(The raw run emits `PASS`/`✔` in green ANSI; colour escapes stripped here, text
otherwise byte-identical. 9 PASS lines, 0 FAIL, exit 0 — no heading or missing
evidence to escalate, and `25-verification.md` was not touched by this stage.)

This gate was run **after** this file first existed and **before** the final
status line below, which is the ordering the stage requires.

## Final status

**GREEN — mutation stage complete, no blocking finding.**

- Verifier PASS carried forward; tier `mvp` so mutation testing is a recorded
  skip (not a gap), with the additional, independent reason that no shell
  mutation lane exists in this repo.
- Zero surviving mutants, zero equivalent mutants (no run).
- Complexity ≤6 gate PASS scoped to the change set; supplementary shell
  measurement max CC 5; `.sh` not covered by the gate's scanner (recorded).
- Full suite re-run after this stage: `make test-scripts` exit 0, 524/524, 0
  failures.
- Audit-trail gate: exit 0, complete.
- Remediation record: **none** (Verifier PASS on attempt 1, phase 1; no BLOCK).
- Nothing committed, pushed, or opened — that is stage 5b (the PR Opener).
  `PR:` line to be appended there.

