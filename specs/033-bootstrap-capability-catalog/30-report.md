# 30-report.md — Mutation Runner report (spec 033)

Stage 5a. Branch `spec/033-bootstrap-capability-catalog`, base ref `main`
(6eb2c99). Working tree dirty — expected at this stage; only the PR Opener
(stage 5b) commits.

Change set under review (bash-only): `scripts/bootstrap.sh` (rewritten into a
thin dispatcher), five new sourced modules (`bootstrap-lib.sh`,
`bootstrap-catalog-lib.sh`, `bootstrap-detect-lib.sh`, `bootstrap-plan-lib.sh`,
`bootstrap-actions.sh`), `scripts/capabilities.tsv`,
`scripts/init-ci.sh`, `scripts/check-loop-files.sh`,
`scripts/tests/bootstrap-capability-catalog.bats`,
`scripts/tests/check-loop-files.bats`, five
`templates/ci-wrappers/*.yml` copy-template sources.

---

## Verifier verdict (carried forward)

**PASS** — `specs/033-bootstrap-capability-catalog/25-verification.md`,
§Remediation cycle 1 — overall verdict (attempt 2, phase 1).

The first Verifier attempt returned **FAIL** on gate ID **AC-033-41** (the
scenario-to-behavior spot check found a test asserting less than its scenario:
the shipped test grepped six `PASS` lines and ignored the gate's exit code,
while `check-loop-files.sh` empirically exited 1 against a `--with-loop` child
repo). The fix came back through the Coder as a `--scope standards|child` mode
plus a two-direction exit-code test, and the scoped re-verification passed.
Remediation accounting is in §Remediation record below.

Stage 5a precondition therefore satisfied.

---

## ⚠ BLOCKING handoff defect — `check-audit-trail.sh` is RED on `25-verification.md`

Not my gate to fix (it belongs to the Verifier's artifact and to the PR
Opener's pre-push check), and I have not touched it. Reporting it because my
own precondition re-check caught it: **the pipeline cannot reach a green draft
PR until it is resolved.**

`scripts/check-audit-trail.sh` requires the five Verifier evidence headings to
match the canonical check names **exactly** (`scripts/check-audit-trail.sh:202-215`:
`tolower(name) == tolower(want)` after stripping only `## Evidence:` and
trailing whitespace). `25-verification.md` heads four of the five blocks with a
suffix, so none of those four match:

| Canonical name the gate wants | Heading actually present |
|---|---|
| `## Evidence: full test suite` | `## Evidence: full test suite (run 1 of 2)`, `(run 2 of 2)`, `(scoped re-run, make test-scripts)` |
| `## Evidence: complexity gate` | `## Evidence: complexity gate (scoped to the change)` |
| `## Evidence: design-principles gate` | `## Evidence: design-principles gate (scoped, -BaseRef main)`, `(full tree)` |
| `## Evidence: scenario-to-behavior spot check` | `## Evidence: scenario-to-behavior spot check — AC-033-41 test (scoped re-run)` |
| `## Evidence: scenario traceability` | exact — the only one that matches |

## Evidence: audit-trail gate (spec folder completeness)

command: bash scripts/check-audit-trail.sh 033-bootstrap-capability-catalog
exit: 1
at: 2026-10-26T00:28:23Z

PASS 033-bootstrap-capability-catalog: 10-tasks.md present and non-empty
PASS 033-bootstrap-capability-catalog: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 033-bootstrap-capability-catalog: 25-verification.md present and non-empty
PASS 033-bootstrap-capability-catalog: 30-report.md present and non-empty
PASS 033-bootstrap-capability-catalog: evidence block 'scenario traceability' — command: scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-10-26T00:04:48Z
FAIL 033-bootstrap-capability-catalog: 25-verification.md has no evidence block for 'full test suite' (AC-015-04/AC-015-14)
FAIL 033-bootstrap-capability-catalog: 25-verification.md has no evidence block for 'complexity gate' (AC-015-04/AC-015-14)
FAIL 033-bootstrap-capability-catalog: 25-verification.md has no evidence block for 'design-principles gate' (AC-015-04/AC-015-14)
FAIL 033-bootstrap-capability-catalog: 25-verification.md has no evidence block for 'scenario-to-behavior spot check' (AC-015-04/AC-015-14)
✘ Audit-trail check: 4 violation(s).

Folder completeness is fine (`30-report.md` present, this file included); the
only failures are the four heading names.

**Prior art shows the intended shape**: archived specs carry a block whose
heading is the exact canonical name — `grep -hE '^## Evidence: (scenario
traceability|full test suite|complexity gate|design-principles gate|scenario-to-behavior spot check)$' docs/changes/*.md`
yields 58 exact-name headings across the archive (10/10/18/10/10). Suffixed
blocks appear there too, but always *alongside* an exact-named block, never
instead of one.

**Minimal correct fix (owner: the Verifier, not me):** rename the four
canonical blocks to the exact names — `## Evidence: full test suite`,
`## Evidence: complexity gate`, `## Evidence: design-principles gate`,
`## Evidence: scenario-to-behavior spot check` — keeping every `command:` /
`exit:` / `at:` marker and all raw output byte-for-byte, and keeping the
suffixed scoped-re-run blocks as additional (non-canonical) evidence. That is a
phase-1 scoped re-verification (attempt 3), not a gate change: `check-audit-trail.sh`
and its `FIVE_CHECKS` array are gate config and off-limits to agents per the
Stop-and-Ask matrix ("fix the code, never the threshold").

I deliberately did **not** edit `25-verification.md`. It is the Verifier's
independent re-check record; a heading rewrite performed by a downstream stage
would blur who asserted what, and the audit contract's whole point is that the
record is self-attested per stage. This is an out-of-scope finding recorded per
the matrix, escalated to the orchestrator for routing.

---

## Conformance tier and whether mutation testing applies

Tier: **`mvp`**.

Determination (no `Conformance tier:` declaration exists in `AGENTS.md` or any
`AGENTS_*.md`, so the floor applies per `docs/CONFORMANCE_TIERS.md` §Tier
assignments — "rules not listed here are `mvp`" — and per
`docs/SPEC_PIPELINE.md` §Stop-and-Ask decision matrix, row "Project type
ambiguous … defer to the harness default (`mvp` tier)"):

## Evidence: conformance tier declaration grep

command: grep -rn "Conformance tier: *\(mvp\|production\|multi-service\)" AGENTS.md AGENTS_*.md
exit: 2
at: 2026-10-26T00:21:55Z

(no matches; `AGENTS_*.md` does not exist, so grep exits 2 — no declaration,
no `production` opt-in)

Corroborated by the repo's own gate, which auto-detects the same tier:
`25-verification.md` Check 3 and Check 3.5 both record `"tier": "mvp"` from
`scripts/check-code-principles.sh`.

Per `docs/SPEC_PIPELINE.md` §Conformance tiers, mutation testing is a
`production`-tier gate ("Architect — mutation testing: skip" at `mvp`;
§Tooling by language: "Mutation testing (`production`+)").

### Tooling fact, independent of tier

No bash/shell mutation lane exists in this repo, at any tier:

- `docs/SPEC_PIPELINE.md` §Tooling by language lists mutation tooling for
  Java (PiTest), Go (`go-mutesting`/`gremlins`), and JS/TS (Stryker) only.
- The repo's mutation template catalog carries one lane per supported
  non-shell language — `ci/templates/go-feature/Makefile` (gremlins),
  `ci/templates/js-feature/package.json` (Stryker), `ci/templates/mutation.mk`,
  `ci/templates/mutants.toml` (cargo-mutants), `ci/templates/mutmut-pyproject.toml`
  (mutmut, Python) — and no shell/bash lane. `make mutation` itself only names
  `mvn verify -Pmutation` / `gremlins unleash` / `npx stryker run`.
- No mutation binary is installed in this environment (checked: `pitest`,
  `stryker`, `go-mutesting`, `gremlins`, `mull` — all absent).

So: mutation score **skipped — `mvp` tier**. This is a recorded skip with
evidence, not a re-run-until-green omission. Had this project been
`production`-tier, bash mutation would still have no lane in this repo's
catalog — a tooling gap to raise as a follow-up, never a threshold to relax.

## Evidence: mutation score

command: make mutation
exit: 0
at: 2026-10-26T00:21:58Z

skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)

## Mutation-kill work

None performed — no mutation run happened, so there are no surviving mutants
and no tests were added by this stage. This stage wrote only this report; it
changed no production code and no test file.

---

## Equivalent mutants

**None.** An equivalent mutant is by definition a survivor of an actual
mutation run; with the run skipped there is no survivor list to adjudicate.
Nothing is being waved through as "un-killable" here — the gate did not run.

This is deliberately not the same claim as "no mutants survive". A bash
mutation lane (e.g. mutating tab-field indexes in `bootstrap-catalog-lib.sh`,
`--dry-run` flag comparisons in `bootstrap-plan-lib.sh`, or the `--scope`
branch in `scripts/check-loop-files.sh`) would produce real, killable
survivors. The skip is tier-and-tooling driven, and recording it as such keeps
that distinction auditable.

---

## Complexity summary (carried from the Refactorer, via Verifier Check 3)

Carried forward from `25-verification.md` §Check 3 and §Check 3.5 — the
Refactorer's before/after measurements are re-recorded there, per the audit
contract.

| Measurement | Result |
|---|---|
| Complexity gate, scoped to the diff (`-BaseRef main`) | exit 0 — `fails: []`, `warns: []` |
| Complexity gate, full tree | exit 1 — 1 FAIL, pre-existing, out of scope (below) |
| Design-principles gate, scoped (`-BaseRef main`) | exit 0 — `fails: []`, `warns: []` |
| Design-principles gate, full tree | exit 1 — same pre-existing FAIL; 16 pre-existing WARNs, all outside the change set |
| Pre-existing FAIL (not this spec) | `./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10` |

Structural claim the Refactorer made — `scripts/bootstrap.sh` split into five
sourced modules so each unit stays small and single-purpose. Measured size of
the resulting units (this stage's own `wc -l`, corroborating the split):

| File | Lines |
|---|---|
| `scripts/bootstrap.sh` (dispatcher) | 311 |
| `scripts/bootstrap-lib.sh` | 431 |
| `scripts/bootstrap-actions.sh` | 439 |
| `scripts/bootstrap-plan-lib.sh` | 178 |
| `scripts/bootstrap-catalog-lib.sh` | 138 |
| `scripts/bootstrap-detect-lib.sh` | 112 |

Honest limitation, same as the Verifier recorded: bash is outside
`check-code-principles.sh`'s CC analyzer (Java/Go/JS-TS/Python/Rust only), so
none of these units has a measured cyclomatic complexity. `shellcheck` is not
installed in this environment, so no bash static analysis backstops it either.
No WARN is being suppressed by this — the scoped gate genuinely finds nothing
in the change because it cannot analyze the language, not because the diff is
clean by measurement.

No design-gate WARN was raised against this change set, so there is nothing to
flag to the PR Opener beyond the pre-existing full-tree items recorded above.

---

## Final test status

Re-run by this stage because the remediation fix touched a shared gate script
and added tests after the Verifier's last run. Full suite, then the spec's own
bats file.

## Evidence: final full test suite

command: make test-scripts
exit: 0
at: 2026-10-26T00:27:37Z

Checking bats assertions are not vacuous...

PASS check-bats-assertions: 56 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..539
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
... (539 `ok` lines total, 0 `not ok`) ...
ok 535 wire: per-answer usage wins over the top-level usage; no top-level usage keeps hosted behavior
ok 536 wire: mixed choice+noul request — low confidence exits 10 with BOTH answers printed
ok 537 wire: answer object with none of answer/choice/noul/score is incomplete, exits 10
ok 538 wire: non-numeric confidence is invalid, exits 10
ok 539 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq

Counts: `ok` = 539, `not ok` = 0, plan `1..539`. Includes all 49 `AC-033-*`
scenarios (`ok 167 AC-033-01` … `ok 215 AC-033-49`).

## Evidence: spec 033 bootstrap bats file

command: bats --tap scripts/tests/bootstrap-capability-catalog.bats
exit: 0
at: 2026-10-26T00:22:43Z

1..49
ok 1 AC-033-01: --list prints every catalog entry as id<TAB>label<TAB>category
ok 2 AC-033-02: --list output is generated from the catalog byte-for-byte
ok 3 AC-033-03: menu, --list and --all all read the one catalog
ok 4 AC-033-04: every catalog entry carries complete fields
... (49 `ok` lines total, 0 `not ok`) ...
ok 47 AC-033-47: orchestration references resolve
ok 48 AC-033-48: skills and gate-consistency gates stay green
ok 49 AC-033-49: no regression in default output or existing init-ci flags

Counts: `ok` = 49, `not ok` = 0.

Harness note for timestamp honesty: a first `make test-scripts` invocation at
`2026-10-26T00:22:01Z` was killed by this stage's tool-call timeout at 120 s
before bats finished — a harness limit, not a test failure. It was re-run with
a 600 s timeout; the run recorded above (00:24:03Z → 00:27:37Z) is the
completed one and is the authoritative result.

**Final test status: PASS** — 539/539 in the full suite, 49/49 in the spec's
own bats file, both exit 0. No failures, no flake observed (the Verifier's two
runs plus this one are all clean).

---

## Gate results (rolled up)

| Gate | Command | Exit | Verdict | Where recorded |
|---|---|---|---|---|
| Scenario traceability | `scripts/check-scenario-traceability.sh --json` | 0 | PASS — 49/49 traced, no dangling refs | `25-verification.md` Check 1 |
| Full test suite | `make test-scripts` | 0 | PASS — 539 ok, 0 not ok (this stage re-ran) | §Final test status above |
| Spec bats file | `bats --tap scripts/tests/bootstrap-capability-catalog.bats` | 0 | PASS — 49 ok, 0 not ok (this stage) | §Final test status above |
| Complexity (scoped) | `scripts/check-code-principles.sh --gates complexity -BaseRef main --json` | 0 | PASS — no FAIL, no WARN in the diff | `25-verification.md` Check 3 |
| Design-principles (scoped) | `scripts/check-code-principles.sh -BaseRef main --json` | 0 | PASS — no FAIL, no WARN in the diff | `25-verification.md` Check 3.5 |
| Design-principles (full tree) | `scripts/check-code-principles.sh --json` | 1 | Pre-existing, out of scope — 1 FAIL + 16 WARNs, none in this change set | `25-verification.md` Check 3.5 |
| Scenario-to-behavior spot check | manual, 4 scenarios probed | — | PASS after remediation (AC-033-41 resolved) | `25-verification.md` Check 4 + cycle 1 |
| Mutation testing | `make mutation` | 0 | **SKIP** — `mvp` tier; no bash mutation lane exists at any tier | §Conformance tier above |
| Property tests | — | — | SKIP — `production` tier gate; exercised by the scoped design-principles run at `mvp` | `25-verification.md` Check 3.5 |
| Audit trail (folder + evidence blocks) | `bash scripts/check-audit-trail.sh 033-bootstrap-capability-catalog` | **1** | **RED — blocks stage 5b**: 4/5 evidence headings missing their exact canonical names in `25-verification.md` | §⚠ BLOCKING handoff defect above |

---

## Remediation record

Bounded-loop accounting per `docs/SPEC_PIPELINE.md` §Remediation budget,
carried forward from `25-verification.md`'s attempt entries and the
orchestrator's loop summary — not guessed.

| # | Gate ID | Phase | Attempt | Resolved by | Status |
|---|---|---|---|---|---|
| 1 | **AC-033-41** (scenario-to-behavior spot check) | **1 — pre-PR** | Verifier attempt 2 (1 retry after the attempt-1 BLOCK) | Coder: added `check-loop-files.sh --scope standards\|child`; rewrote the test to assert real exit codes both ways | **Resolved** — scoped re-verification PASS |

Loop counters from the orchestrator's loop summary (`runs.jsonl`, appended by
the orchestrator, verbatim):

```
{"specSlug":"033-bootstrap-capability-catalog","gatesFailed":["spot-check"],"warnings":[],"durationSec":660,"outcome":"fail","runId":"19d88ed3-22bf-4cc5-adcb-7f72b84bff40","loopCount":1,"phase1Retries":0,"phase2Retries":0}
{"specSlug":"033-bootstrap-capability-catalog","gatesFailed":[],"warnings":[],"durationSec":300,"outcome":"pass","runId":"e8c46977-5718-47f7-9732-83a4e41de941","loopCount":2,"phase1Retries":1,"phase2Retries":0}
```

So: **phase 1, cycle 1, one retry, resolved at attempt 2** — consistent with
`25-verification.md` §Remediation cycle 1.

- **Phase 2 (post-PR CI):** none — `phase2Retries: 0`; the PR is not open yet.
- **Phase 3 (deploy verification):** not reached (non-frontend lane; runs only
  after stage 5b).
- **Budget state:** phase 1 used 1 of 3, phase 2 used 0 of 3. Neither budget was
  exhausted; no escalation is due.

---

## Out-of-scope findings (recorded, not fixed)

1. **`check-audit-trail.sh` exits 1 on this spec folder** — the four suffixed
   Verifier evidence headings. Full detail in §⚠ BLOCKING handoff defect above;
   listed here too because it is the one item on this list that actually stops
   the pipeline rather than merely being noted. Owner: Verifier (heading rename
   in a phase-1 scoped re-verification). **Do not open the draft PR before it is
   green.**
2. **`runs.jsonl` is modified in the working tree** — `git diff --stat` shows
   2 insertions, both orchestrator telemetry lines for this spec (the two
   JSONL records quoted above). It is a tracked file, outside spec 033's
   subject matter. The PR Opener decides whether pipeline telemetry belongs in
   this commit (prior specs appear to have committed it); this stage neither
   reverts nor commits it.
3. **Full-tree design-principles FAIL is pre-existing** —
   `skills/hallmark/site/examples/cobalt-01/script.js` CC=10, plus 16 WARNs in
   `ci/templates/*` and `skills/hallmark/*`. Untouched by this change set; not
   this spec's defect. A separate follow-up spec, not a silent fix here.
4. **No bash mutation lane and no `shellcheck`** — the change set is 1,000+
   lines of shell whose only verification is bats behavioral tests plus a
   language-blind complexity gate. Worth a follow-up spec if this repo ever
   graduates to `production` tier; recorded so the gap is visible rather than
   implied-green.

---

## Summary for the PR Opener

- Verifier: **PASS** (remediation cycle 1, phase 1, attempt 2).
- Mutation score: **skipped — `mvp` tier** (and no bash mutation lane exists at
  any tier). No equivalent mutants — no run, no survivors.
- Final full suite: **539 ok / 0 not ok**, exit 0. Spec bats file: **49 ok /
  0 not ok**, exit 0.
- Complexity: scoped gate exit 0 with no FAIL/WARN; the one full-tree FAIL is
  pre-existing and out of scope.
- No production code and no test file was changed by this stage — this report
  is its only artifact.
- **STAGE 5A VERDICT: GREEN** on its own gates (mutation skip recorded, full
  suite green, complexity carried).
- **BUT: do not open the PR yet.** Your pre-push gate
  `scripts/check-audit-trail.sh` exits **1** on this folder: four of the five
  Verifier evidence headings in `25-verification.md` are suffixed rather than
  the exact canonical names the gate matches. Route to the Verifier for the
  heading rename (§⚠ BLOCKING handoff defect). Re-run the audit gate before
  trusting a green PR.


---

## PR record (stage 5b)

PR: https://github.com/RexiAI/my-engineering-standards/pull/100
Commit count: 9 (8 task/spec commits + 1 record commit)
