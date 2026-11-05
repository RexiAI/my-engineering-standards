# 039 — Pipeline lite mode: mutation and final report

- **Stage:** 5a, Mutation Runner.
- **Worktree:** `/home/dbueno/.local/share/opencode/worktree/471827/spec-039` (detached HEAD, `f0188e6`).
- **Pipeline mode for this run:** `full` — carried from `25-verification.md` attempt 2. No `Conformance tier:` declaration exists, so the tier guard refuses `lite`; independently the classifier returns `full` (`Reason: 7 files named under scripts/ — lite allows at most one`). All stages run, including this one.
- **Conformance tier:** `mvp` (repo declares no tier; `mvp` is the floor per `docs/CONFORMANCE_TIERS.md`).
- **Mutation score:** **skipped — `mvp` tier** (`production`-tier gate, not run by policy; see §Evidence: mutation score).
- **Final test status:** **PASS — 807/807 `ok`, 0 `not ok`, 0 skips** (`make test`, exit 0).
- **Report verdict:** **GREEN**.

## Verifier verdict (carried forward, not re-derived)

`25-verification.md` attempt 2 (phase 1) reads:

- `- **Verdict:** **PASS**.` (§Verdict, round 2)
- Gate summary: traceability PASS, full suite PASS (807/807 `ok`, 0 skips), complexity PASS, design-principles PASS (0 FAIL), scenario-to-behavior spot check PASS.
- Attempt 1 (`FAIL`, gate `spot-check`) is historical: the relative-path non-termination in `scripts/resolve-pipeline-mode.sh` was fixed and re-verified in round 2.

This stage treats that verdict as the precondition, not as its own result. It re-ran the
full suite independently below because the Verifier's PASS predates this stage.

## Evidence: mutation score

command: make mutation
exit: 0
at: 2026-11-05T12:14:41Z

```
skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)
```

Per `docs/SPEC_PIPELINE.md §Conformance tiers` and `docs/spec-pipeline/coder.md
§Conformance tiers`, mutation testing is a `production`-tier gate. This repo
declares no tier, so the ruling is `mvp` and mutation testing is a recorded
skip, not a gap.

Tier evidence:

```
$ shopt -s nullglob; files=(AGENTS.md AGENTS_*.md); grep -rn "Conformance tier: production" "${files[@]}"
(no output)
exit: 1

$ grep -rn "Conformance tier: mvp" "${files[@]}"
(no output)
exit: 1
```

Neither `mvp` nor `production` is declared anywhere at the repo root, which is
exactly the state `docs/spec-pipeline/lite-mode.md` documents as "lite is inert
here by design" (an undeclared repo is treated as possibly production). The
`make mutation` target's own tier probe and the design-principles gate's
`"tier": "mvp"` (recorded in `25-verification.md`, both attempts) agree.

Secondary confirmation that no mutation engine could run even at a higher tier:
this change set is bash + markdown + bats. Changed-path extensions are `19 md`,
`3 sh`, `2 bats`, `1 bash`, `1 jsonl` (`runs.jsonl` telemetry), plus the
untracked `specs/` folder. There is no `pom.xml`, `package.json`, `go.mod`,
`stryker.conf.*`, or `gremlins.yaml` in the tree — no PiTest, gremlins, or
Stryker target exists to point at the change. Per the stage instruction this
tooling gap is reported, not used to block.

### Equivalent mutants

**None.** No mutation engine ran, so no mutant was generated, survived, or was
judged equivalent. There is no un-killable-mutant list to name. No mutation-kill
tests were written, so this stage added no test code to the suite.

## Complexity summary (carried from the Refactorer)

The Refactorer leaves no report artifact by design (`docs/SPEC_PIPELINE.md
§What each stage leaves behind`), and the orchestrator's loop summary carries no
per-function complexity table for this run. Nothing is invented here; the
values below are the ones the Verifier re-recorded, plus this stage's own
scoped re-measurement.

- **Verifier's re-recorded complexity (attempt 2, scoped to `scripts/`):** 0 FAIL,
  39 WARN, all pre-existing comment-heuristic findings in files this spec does
  not touch; `shellcheck -x` clean on the three new scripts.
- **This stage, `scripts/check-code-principles.sh --gates complexity --json scripts`:**
  `{"tier":"mvp","gates":["complexity"],"fails":[],"warns":[]}` — exit 0.
- **Refactorer's one recorded structural change** was behavior-preserving:
  `scripts/tests/ac-031-doc-section.bash` extracted `section_of` out of
  `section`; the ac-031 bats files were untouched and re-ran 78/78 `ok`
  (`25-verification.md` attempt 1, §no unaccounted behavior).

## Evidence: final test status

command: make test
exit: 0
at: 2026-11-05T12:22:34Z

```
Checking bats assertions are not vacuous...
PASS check-bats-assertions: 77 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..807
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
[... 804 TAP lines omitted, all `ok` ...]
ok 807 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)
```

```
$ grep -m1 -E '^1\.\.' /tmp/opencode/039-r3-final-test.log
1..807
$ grep -cE '^ok [0-9]+' /tmp/opencode/039-r3-final-test.log
807
$ grep -cE '^not ok' /tmp/opencode/039-r3-final-test.log
0
$ grep -cE '^# (skip|SKIP)' /tmp/opencode/039-r3-final-test.log
0
$ grep -n 'relative spec path' /tmp/opencode/039-r3-final-test.log
245:ok 240 unit: a relative spec path with an undetectable tier resolves full and terminates
```

Started `2026-11-05T12:22:34Z`, finished `2026-11-05T12:29:39Z` (425 s wall
clock). This run was made *after* `30-report.md` was written, so the recorded
final status matches the exact artifact state the PR Opener will see. 807 of 807
`ok`; the single `not ok` substring is part of the *name* of an existing passing
test (`AC-001-02`), not a failure — `grep -cE '^not ok'` is 0. The relative-path
regression test added by the phase-1 fix is present and green.

An earlier independent run on the same source tree (before the report existed,
`2026-11-05T12:14:44Z` → `12:21:44Z`, log
`/tmp/opencode/039-r3-test.log`) produced the same result: `1..807`, 807 `ok`,
0 `not ok`, 0 skips, exit 0. Two consecutive green runs, identical plan.

Because mutation testing was skipped, this stage added no tests; the full suite
here is the same plan the Verifier saw (`1..807`), re-executed independently
after the Verifier's run.

## Evidence: read-cost gate (supporting, WARN)

command: bash scripts/measure-stage-read-cost.sh
exit: 0
at: 2026-11-05T12:22:02Z

```
Stage read cost — baseline 50836 bytes, budget 50% (= 25418 bytes)
stage               bytes   ratio  verdict
specifier           15092   0.296  ok
ux                  14315   0.281  ok
coder               16286   0.320  ok
refactorer          14317   0.281  ok
verifier            22250   0.437  ok
mutation-runner     21414   0.421  ok
pr-opener           25346   0.498  ok
deployer            16483   0.324  ok
```

Gate is green (exit 0), but `pr-opener` sits at **0.498 of the 0.500 ceiling —
72 bytes of headroom**. `docs/spec-pipeline/pr-opener.md` gained a `## Lite mode`
section in this change set. The next line added to that file, or to its
`Must read` set, flips the gate red. Recorded as a WARN for the Architect /
next spec; not a FAIL, not fixed here.

## Evidence: audit-trail gate (supporting)

command: bash scripts/check-audit-trail.sh 039-pipeline-lite-mode
exit: 0
at: 2026-11-05T12:29:51Z

```
PASS 039-pipeline-lite-mode: 10-tasks.md present and non-empty
PASS 039-pipeline-lite-mode: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 039-pipeline-lite-mode: 25-verification.md present and non-empty
PASS 039-pipeline-lite-mode: 30-report.md present and non-empty
PASS 039-pipeline-lite-mode: 45-decisions.md optional without an 'Autopilot: true' marker (AC-035-35)
PASS 039-pipeline-lite-mode: evidence block 'scenario traceability' — command: bash scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-11-01T16:19:17Z
PASS 039-pipeline-lite-mode: evidence block 'full test suite' — command: make test, exit: 0, at: 2026-11-01T16:19:42Z
PASS 039-pipeline-lite-mode: evidence block 'complexity gate' — command: bash scripts/check-code-principles.sh --gates complexity --json scripts, exit: 0, at: 2026-11-01T16:35:58Z
PASS 039-pipeline-lite-mode: evidence block 'design-principles gate' — command: bash scripts/check-code-principles.sh --json, exit: 0, at: 2026-11-01T16:29:32Z
PASS 039-pipeline-lite-mode: evidence block 'scenario-to-behavior spot check' — command: timeout 5 bash scripts/resolve-pipeline-mode.sh specs/s lite, exit: 124, at: 2026-11-01T16:35:26Z
✔ Audit-trail check: specs/039-pipeline-lite-mode complete, verifier evidence recorded.
```

The gate is green. Its parsed spot-check line shows attempt 1's historical
`exit: 124` because `check-audit-trail.sh` takes the **first** block per check
name and `25-verification.md` carries attempt 1 before round 2; the current
evidence is round 2's `exit: 0` block (`at: 2026-11-05T12:05:44Z`). The gate
therefore passes on a folder whose printed spot-check evidence is a superseded
FAIL — see WARN 6.

## WARNs flagged to the Architect (not FAILs, not fixed)

1. **Read-cost headroom is 72 bytes** on `pr-opener` (0.498 / 0.500). This
   change set added the `## Lite mode` section to that stage document. The next
   addition to it, or to its Must-read set, breaks the gate.
2. **Lite mode is inert in this repo until a tier declaration exists.** No
   `Conformance tier:` heading is reachable from `specs/039-pipeline-lite-mode`,
   so the guard refuses `lite` on every run and the classifier independently
   returns `full`. That is the documented conservative behavior (an undeclared
   repo is treated as possibly production), not a defect — but it means this
   spec's feature cannot activate here until someone adds
   `## Conformance tier: mvp`, and no pipeline run exercises the lite path end
   to end. The lite path is covered by tests and document assertions only.
3. **`specs/039-pipeline-lite-mode/45-decisions.md` does not exist.** The
   orchestrator never invoked `scripts/resolve-pipeline-mode.sh` for this
   spec's own run (unchanged from both Verifier attempts). The resolver writes
   correct entries when called (three live entries reproduced by the Verifier);
   the gap is orchestrator-side wiring. This stage did not create the file
   (out of scope, and inventing a resolution record would falsify the audit
   trail).
4. **Cosmetic:** `20-acceptance/AC-039-03-tier-guard.md:17` title is a bare noun
   (`## AC-039-03-03 — Multi-service`) after the `(pending Q2)` suffix was
   removed; siblings carry verbs. ID-stable, no behavioral divergence.
5. **Heuristic false positive:** `scripts/classify-spec-size.sh:28` is flagged
   as commented-out code; it is the exit-code line of the script's own usage
   banner. 0 FAIL, recorded per contract.
6. **Tooling observation (out of scope, follow-up candidate):**
   `scripts/check-audit-trail.sh` takes the first evidence block per check name.
   After a phase-1 remediation rewrites the same check, the gate reports the
   superseded block — here it prints `spot check … exit: 124` (attempt 1's
   FAIL) while passing. It never inspects the exit code, so this does not
   mask a regression today, but the printed line misrepresents current evidence.
   Proposed follow-up: parse the last block per check, or assert `exit: 0`.

## Remediation record

One BLOCK occurred during this spec's run, before this stage:

| BLOCK | Phase | Resolved at attempt | Evidence |
|---|---|---|---|
| Gate `spot-check` FAIL — `scripts/resolve-pipeline-mode.sh` never returns on the documented relative invocation when the tier is undetectable (AC-039-03-04 violated) | 1 (pre-PR) | **attempt 2 of 3** | `25-verification.md` attempt 1 §Verdict (`FAIL`, route to `spec-coder`); round 2 (`attempt 2, phase 1`) `PASS` after the canonicalisation fix + relative-path bats regression test. `runs.jsonl` loop summary agrees: `247cedc9…` `outcome: fail`, `loopCount: 1`, `phase1Retries: 0` → `a63e512c…` `outcome: pass`, `loopCount: 2`, `phase1Retries: 1`. |

No phase-2 (post-PR) or phase-3 (deploy) BLOCK exists yet — the PR is not open,
so those loops have not run. Budgets not exhausted (1 of 3 phase-1 attempts used
beyond the original run).

This stage (5a) itself raised no BLOCK: mutation testing is a policy skip and
the final suite is green.

## Working tree state

`git status --porcelain` is dirty, and every dirty path belongs to this spec's
change set or its telemetry — the expected pre-commit state for stage 5a, left
untouched for the PR Opener (stage 5b):

- modified: `agents/spec-pipeline.md`, `commands/build.md`, `docs/SPEC_PIPELINE.md`,
  `docs/adr/README.md`, `docs/spec-pipeline/{coder,pr-opener,verifier}.md`,
  `scripts/tests/ac-031-doc-section.bash`, `runs.jsonl` (orchestrator telemetry)
- untracked: `docs/adr/0020-pipeline-lite-mode.md`,
  `docs/spec-pipeline/lite-mode.md`, `scripts/{classify-spec-size,lite-trigger,resolve-pipeline-mode}.sh`,
  `scripts/tests/ac-039-{lite-mode,lite-wiring}.bats`, `specs/`

Nothing was stashed, committed, pushed, or opened as a PR by this stage. No
gate threshold was changed.

## Verdict

**GREEN.** Verifier PASS carried forward; mutation score `skipped — mvp tier`
with the tier ruling evidenced; no equivalent mutants exist to name; the full
suite re-ran green at 807/807 with 0 failures and 0 skips; the only findings are
the six non-blocking WARNs above. Stage 5b (the PR Opener) may proceed.

## PR

PR: https://github.com/RexiAI/my-engineering-standards/pull/114
Commits: 9
