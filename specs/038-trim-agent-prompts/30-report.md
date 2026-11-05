# 30 — Mutation / Architect report: 038-trim-agent-prompts

**Stage:** 5a (Mutation Runner) · **tier:** `mvp` · **worktree:** `spec-038`
**HEAD:** detached at `f0188e6` (spec-037 tip); spec-038 changes in the working tree, uncommitted (expected pre-stage-5b state — the verifier recorded the same tree).
**Verified against:** `specs/038-trim-agent-prompts/10-tasks.md` + `20-acceptance/`, plus the Verifier's `25-verification.md`. `00-informal.md` was not read.

## Verdict

**GREEN.** Mutation testing is a `production`-tier gate (`docs/SPEC_PIPELINE.md §Conformance tiers`); this project is `mvp`, so it is **skipped** with a recorded reason, not failed. Every gate that does apply is green on a fresh run: the full suite is 788/788 `ok`, `make validate-all` exits 0, the agent line cap is 9/9, and the read-cost budget holds.

| # | Row | Value | Source |
|---|---|---|---|
| 1 | Verifier verdict (carried forward) | **PASS — attempt 2, phase 1** (attempt 1 also PASS; 788 `ok`, 0 `not ok`) | `25-verification.md` §Round-2 verdict + §Round-2 record |
| 2 | Mutation score | **skipped — `mvp` tier** (`production`-tier gate; `make mutation` prints the skip and exits 0) | Evidence block below |
| 3 | Equivalent mutants | **none** — no mutation run at this tier, so none to classify | n/a |
| 4 | Complexity summary (carried from Refactorer, re-confirmed here) | PASS — `shellcheck -S warning` exit 0 on all 7 changed shell files, `bash -n` exit 0, design-principles `complexity` category 0 FAIL (3 pre-existing `KISS_LINES` WARNs, 0 in a changed file) | §Complexity summary + evidence below |
| 5 | Final full test suite | **PASS — 788 `ok`, 0 `not ok`, 0 `# skip`, plan `1..788`** | Evidence block below |
| 6 | Supplementary repo gates | PASS — `make validate-all` exit 0, `check-agent-line-cap.sh` exit 0 (9/9), `measure-stage-read-cost.sh` exit 0 | Evidence blocks below |
| 7 | Remediation record | **no BLOCK occurred**; one phase-1 remediation round (attempt 1 → attempt 2), resolved at attempt 2 | §Remediation record |
| 8 | PR Opener precondition | branch will be `spec/038-trim-agent-prompts`, this report exists and is GREEN; one staging caveat (U-1) below | §Hand-off to stage 5b |

## Evidence: mutation testing (skip at tier)

command: make mutation
exit: 0
at: 2026-11-05T12:50:11Z

```
skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)
```

The skip is the Makefile's own tier probe (`Makefile:135-141`), not an ad-hoc decision: it greps for `Conformance tier: production` in `AGENTS.md`/`AGENTS_*.md`, finds `mvp`, and prints the documented reason. Per `docs/SPEC_PIPELINE.md §Conformance tiers`, the Architect role still runs at `mvp` (to carry the report to stage 5b); only the mutation *test* is omitted. No Stryker/PiTest/`gremlins` invocation exists for this repo's shell + markdown surface, and no `stryker.conf.*` / `pom.xml` / `go.mod` is present to host one.

## Evidence: final full test suite

command: make test-scripts
exit: 0
at: 2026-11-05T12:42:56Z

Started `2026-11-05T12:42:56Z`, finished `2026-11-05T12:50:02Z` (426 s, full log `/tmp/opencode/mut-038/final-suite.log`).

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 79 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..788
ok 224 AC-038-02-01 — self-ci runs the agent line-cap check
ok 225 AC-038-02-02 — AGENTS.md documents the line-cap check
ok 228 AC-038-04-01 — every gate script the agents cited before the trim is still reachable
ok 229 AC-038-04-02 — the complexity threshold is still 6
ok 230 AC-038-04-02 — the skill line-limit threshold is still 500
ok 231 AC-038-04-02 — the new agent line cap is the spec's 120, not a looser value
ok 232 AC-038-05-01 — check-orchestration, check-skills, and check-agent-line-cap all exit 0
ok 236 AC-038-01-01 — every agents/spec-*.md within the cap makes the check exit 0
ok 237 AC-038-01-02 — a fixture agent at exactly 120 lines passes
ok 238 AC-038-01-03 — a fixture agent at 121 lines fails and names the path and count
ok 239 AC-038-01-04 — a 500-line non-spec agent is ignored
ok 244 AC-038-03-01 — every formerly over-cap agent is at or under 120 lines
ok 245 AC-038-03-02 — every scripts/ or skills/ path a trimmed agent cites exists
...
ok 786 unit: a cap smaller than the marker still never exceeds the cap
ok 787 unit: state exactly at the cap is not truncated and emits no reason
ok 788 unit: successful under-cap call writes no reason line at all
```

Counted from the raw TAP log: `^ok ` **788**, `^not ok` **0**, `^# skip` **0**, plan line `1..788`. Excerpt elides untouched tests only; the `AC-038-*` lines, the plan line and the tail are verbatim. This is the Verifier's 788 re-confirmed from a clean re-run — no new test code was written this stage (mutation testing is skipped), so there is no mutation-kill delta to absorb.

## Evidence: complexity gate

command: shellcheck -S warning scripts/check-agent-line-cap.sh scripts/tests/ac-038-line-cap.bats scripts/tests/ac-038-gates-intact.bats scripts/tests/ac-038-trimmed-agents.bats scripts/tests/ac-038-ci-wiring.bats scripts/tests/test_helper.bash tests/AC-030-01.sh
exit: 0
at: 2026-11-05T12:50:11Z

```
(no output — shellcheck is silent when clean)
```

command: bash -n scripts/check-agent-line-cap.sh && bash -n scripts/tests/test_helper.bash && bash -n tests/AC-030-01.sh
exit: 0
at: 2026-11-05T12:50:11Z

```
(no output — all three files parse)
```

command: scripts/check-code-principles.sh . --gates complexity --json
exit: 0
at: 2026-11-05T12:50:11Z

```
{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "111" }]
}
```

`fails: []`. The three WARNs are pre-existing KISS line-length hints in files this spec did not touch; there is **no cyclomatic-complexity finding**, and no WARN lands in a changed file.

## Complexity summary (carried from the Refactorer)

The Refactorer writes no report artifact by design (`docs/SPEC_PIPELINE.md §Audit contract`); its structural claims are re-executed by the Verifier and re-recorded in `25-verification.md`, and I re-confirm them here rather than inventing numbers:

| Concern | Mechanism | Result |
|---|---|---|
| Cyclomatic complexity ≤6 | `check-code-principles.sh` complexity analyzer | **0 FAIL / 0 CC WARN**; the analyzer deliberately skips `*.sh` (`scripts/check-code-principles.sh:450`), and this diff is shell + markdown only |
| Shell correctness / lint | `shellcheck -S warning` (project linter) | **exit 0**, all 7 changed/new shell files silent |
| Shell parse | `bash -n` | **exit 0** on script + helper + `tests/AC-030-01.sh` |
| Duplication | design-principles `dry` category | **0 FAIL**; 58 WARNs repo-wide, **0 touching a changed file** (Verifier round 2) |
| Property tests | `production`+ only | **skipped — `mvp` tier** (same tier rule as mutation) |
| Agent prompt size | `check-agent-line-cap.sh` | **9/9 within 120**; max `spec-deployer.md` 118 |

## Evidence: supplementary repo gates

command: make validate-all
exit: 0
at: 2026-11-05T12:50:05Z

```
[WARN] skills/hallmark/SKILL.md — Body has 562 lines (>500 limit recommended by Agent Skills spec; move details to references/)

All SKILL.md files valid (1 warning(s)).
All validations passed.
```

command: ./scripts/check-agent-line-cap.sh
exit: 0
at: 2026-11-05T12:50:05Z

```
All 9 agent prompt(s) within the 120-line cap.
```

command: scripts/measure-stage-read-cost.sh
exit: 0
at: 2026-11-05T12:50:05Z

```
Stage read cost — baseline 50836 bytes, budget 50% (= 25418 bytes)
stage               bytes   ratio  verdict
specifier           14441   0.284  ok
ux                  19663   0.386  ok
coder               15379   0.302  ok
refactorer          13666   0.268  ok
verifier            24401   0.479  ok
mutation-runner     20763   0.408  ok
pr-opener           24906   0.489  ok
deployer            18744   0.368  ok

Every stage reads at most 50% of the unsplit document.
```

The `skills/hallmark` WARN is pre-existing and untouched by this spec. `validate-all` = `validate validate-docs validate-refs validate-skills`, so this run also re-confirms `check-orchestration.sh` and `check-skills.sh` behind AC-038-05-01.

## Evidence: audit-trail gate (this report)

command: ./scripts/check-audit-trail.sh 038-trim-agent-prompts
exit: 0
at: 2026-11-05T12:50:50Z

```
PASS 038-trim-agent-prompts: 10-tasks.md present and non-empty
PASS 038-trim-agent-prompts: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 038-trim-agent-prompts: 25-verification.md present and non-empty
PASS 038-trim-agent-prompts: 30-report.md present and non-empty
PASS 038-trim-agent-prompts: 45-decisions.md optional without an 'Autopilot: true' marker (AC-035-35)
PASS 038-trim-agent-prompts: evidence block 'scenario traceability' — command: scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-11-05T11:58:17Z
PASS 038-trim-agent-prompts: evidence block 'full test suite' — command: make test-scripts, exit: 0, at: 2026-11-05T11:58:25Z
PASS 038-trim-agent-prompts: evidence block 'complexity gate' — command: shellcheck -S warning scripts/check-agent-line-cap.sh scripts/tests/ac-038-line-cap.bats scripts/tests/ac-038-gates-intact.bats scripts/tests/ac-038-trimmed-agents.bats scripts/tests/ac-038-ci-wiring.bats scripts/tests/test_helper.bash, exit: 0, at: 2026-11-05T12:05:48Z
PASS 038-trim-agent-prompts: evidence block 'design-principles gate' — command: scripts/check-code-principles.sh . --json, exit: 0, at: 2026-11-05T12:05:39Z
PASS 038-trim-agent-prompts: evidence block 'scenario-to-behavior spot check' — command: scripts/check-agent-line-cap.sh /tmp/opencode/verify-038/fixture, exit: 1, at: 2026-11-05T12:07:02Z
✔ Audit-trail check: specs/038-trim-agent-prompts complete, verifier evidence recorded.
```

Run without `--require-deploy` (stage 5b's invocation, `docs/SPEC_PIPELINE.md §The gate`); this lane is non-frontend, so stage 5c records a skip rather than a deploy artifact.

## Equivalent mutants

**None.** Mutation testing was not run (`mvp` tier), so no mutant survived and none needs an un-killable classification. This spec's test surface is shell + markdown assertions, which a JS/Python mutation runner cannot meaningfully mutate anyway; the tier rule and the tooling reality agree.

## Stats

**Test surface**

| Metric | Attempt 1 (Verifier) | Final (this stage) |
|---|---|---|
| bats tests | 786 `ok` | **788 `ok`**, 0 `not ok`, 0 skip |
| bats files guarded by anti-vacuity check | 79 | 79 |
| delta vs attempt 1 | — | +2 (W-1 negative fixture + positive companion, `ok 233`–`ok 235` in round 2) |

**Agent prompts (always-loaded) vs stage docs (on-demand)** — carried from the Verifier's measurement, unchanged by this stage:

| File | HEAD → now | Δ bytes |
|---|---|---|
| `agents/spec-verifier.md` | 13974 → 7236 | −6738 |
| `agents/spec-ux.md` | 10502 → 5795 | −4707 |
| `agents/spec-pr-opener.md` | 9493 → 6643 | −2850 |
| `agents/spec-deployer.md` | 7295 → 6068 | −1227 |
| four-prompt total | — | **−15522 (−43.2%)** |
| `docs/spec-pipeline/{verifier,ux,deployer,pr-opener}.md` | — | +14459 (on demand) |
| net across both sets | — | **−1063** |

**Line counts:** 9/9 `agents/spec-*.md` ≤120; largest are `spec-deployer.md` 118, `spec-ux.md` 117, `spec-verifier.md` 117; total 930 lines across the 9 prompts.

**Read-cost headroom:** verifier 24401/25418 (**1017 B** free), pr-opener 24906/25418 (**512 B** free) — still tight, see W-5 below.

**Change set:** 14 tracked files changed (+557 / −585), 5 new in-scope files (`scripts/check-agent-line-cap.sh` + 4 `scripts/tests/ac-038-*.bats`), 1 new ADR (`docs/adr/0020-agent-prompt-line-cap.md`), plus the spec folder itself.

## Findings carried forward

- **W-2r (residual, not a FAIL).** `docs/spec-pipeline/ux.md:28` still shows metavariable placeholders in its illustrative criteria snippet (`"<the applicability question>"`, `"<frontend surface definition>"`, …). The authoritative loaded prompt (`agents/spec-ux.md:38`) carries the real criteria text and says "pass them verbatim", so behavior is correct today; the residual risk is a future editor copying the snippet instead of the prompt. Cheap follow-up: mirror the real criteria into the stage-doc snippet. Recorded per the Stop-and-Ask matrix ("Out-of-scope finding → record, do not fix").
- **U-1 (unaccounted working-tree edit, out of this spec's tasks).** `tests/AC-030-01.sh` rewrites four `printf … | grep -q` pipelines to here-strings and hoists `body_of "$SK"` out of the loop. This is exactly the latent defect **O-2 in spec 037** (`printf` takes SIGPIPE when `grep -q` exits early and `set -o pipefail` propagates it) — the fix shape 037 recommended. It is behavior-preserving (both versions green, shellcheck silent) and no 038 acceptance criterion covers it. **Recommendation: keep it, as its own commit**, e.g. `fix(tests): avoid printf|grep -q SIGPIPE flake in AC-030-01 (037 O-2)`, staged separately from the 038 task commits so it does not ride inside an unrelated `feat` commit. Do not revert — it removes a real timing-dependent flake. Contract note: 037 closed as PASS with O-2 recorded out of scope, so this commit should cite 037 O-2 in its message.
- **W-5 (budget observation).** Read-cost margin is thin again: verifier 1017 B, pr-opener 512 B free, both printing `0.479`/`0.489` against `0.500`. The gate passes; the next line added to either stage doc turns it red. Any follow-up spec touching `docs/spec-pipeline/{verifier,pr-opener}.md` must budget for it.
- **O-1 / O-2 (pre-existing, from the Verifier).** `self-ci.yml`'s shellcheck step still carries `continue-on-error: true`; ADR 0020's "four over-cap agents" vs `10-tasks.md`'s five is a timing artifact (037 had already trimmed `spec-pipeline.md`). Neither is this spec's to fix.

## Remediation record

Carried forward from `25-verification.md` §Re-verification record and the orchestrator's run ledger (`runs.jsonl`, the two `038-trim-agent-prompts` rows):

| Phase | Attempt | Trigger | Outcome |
|---|---|---|---|
| phase 1 | attempt 1 | first full verification run | **PASS with 5 findings** (W-1..W-5) — a PASS, not a BLOCK |
| phase 1 | attempt 2 | W-1..W-5 remediation | **PASS**; all five remediations independently re-executed; two residual notes (W-2r, U-1) |

**No BLOCK occurred during this run.** No gate reached the fix-the-code budget; the only re-run was the scoped phase-1 re-verification of the attempt-1 review findings. This matches the ledger's counters for loop 2 of this spec: `phase1Retries: 1`, `phase2Retries: 0`. No phase-2 (post-PR CI) round has run yet — stage 5b has not opened the PR.

## Working tree

Dirty by design at this stage: the 038 change set is uncommitted, as stage 5b commits one conventional commit per task. Dirty paths are the 14 tracked modifications, the 5 new in-scope files, the ADR, the spec folder, plus two non-038 paths — `runs.jsonl` (orchestrator telemetry, uncommitted by instruction) and `tests/AC-030-01.sh` (U-1, recommend a separate commit). Nothing was staged, committed, stashed, or reverted by stage 5a.

## Hand-off to stage 5b

Mutation gate: **skipped at `mvp`** (documented, not silently absent). Everything else GREEN. The PR Opener's precondition (`docs/SPEC_PIPELINE.md §Stop-and-Ask decision matrix`: branch `spec/NNN-slug`, `30-report.md` present and green) is satisfiable. The only staging instruction is U-1: commit `tests/AC-030-01.sh` as its own `fix(tests): …` commit referencing 037 O-2, or leave it uncommitted — do not fold it into a 038 task commit.
