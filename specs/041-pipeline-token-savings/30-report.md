# 30-report — 041-pipeline-token-savings

Mutation score: skipped — mvp tier
Final test status: green
Verifier verdict: PASS
Autopilot: false
PR: (appended by stage 5b — the PR Opener)

## Scope

Stage 5a, Mutation Runner. Read `25-verification.md` first: verdict **PASS** at
attempt 2, phase 1 (round-2 scoped re-verification). Proceeded on that verdict.
Wrote this report and `/tmp` logs only — no production-code edit, no test edit,
no commit, no push, no branch or tag operation.

Conformance tier is `mvp` (`scripts/check-code-principles.sh --gates complexity
--json` reports `"tier": "mvp"`; `docs/SPEC_PIPELINE.md §Conformance tiers`).
Mutation testing is a `production`+ gate, so it was not run. No mutation tooling
(`pom.xml`, `package.json`, `stryker.conf.*`) is configured in this repo either.

## Verifier verdict (carried forward)

**PASS — attempt 2, phase 1.** Every round-2 gate ran and produced no findings.
Round-1 findings B1 (107 false signal lines on the green suite), B2 (circular
reuse protocol) and B3 (stale hashes / slash-token conflict in
`20-acceptance/`) were resolved by the fix; F1 was justified with a verified
revert claim. Round-1 `design-principles` (exit 0; 0 FAIL, 60 WARN) carried
forward per §Scoped re-verification.

| # | Check | Gate ID | Round-2 result |
|---|---|---|---|
| 1 | Scenario traceability | `traceability` | PASS — exit 0, all 54 scenarios traced |
| 2 | Full test suite | `test-suite` | PASS — exit 0, 877 `ok`, 0 `not ok`, 0 `# SKIP`, `signal=0` |
| 3 | Complexity gate | `complexity` | PASS — 0 FAIL; `shellcheck` exit 0 |
| 4 | Scenario-to-behavior spot check | `spot-check` | PASS — B1/B2/B3/F1 resolved |
| 5 | No unaccounted behavior | `unaccounted` | PASS — F1 accounted by AC-037-03-01 |

## Mutation testing

**Skipped — `mvp` tier.** `production` is the lowest tier at which the mutation
*test* runs (the Architect role still runs at `mvp` for the PR tail, but not the
mutation gate). No mutants were generated, so no surviving mutants exist and no
mutation-killing tests were written.

**Equivalent mutants: none** — not "none found", but not applicable: mutation
testing was not run, so there is no mutant population to classify. Nothing is
claimed to be un-killable.

## Complexity summary (carried from the Refactorer)

The Refactorer writes no report artifact by design
(`docs/SPEC_PIPELINE.md §Audit contract`); the Verifier re-ran the complexity
lane in round 2 after the fix touched `scripts/agent-test-summary.sh` and
`scripts/test-run-reuse.sh`. Re-run here, identical result:

- `scripts/check-code-principles.sh --gates complexity --json` → exit 0,
  tier `mvp`, `"fails": []`, **0 FAIL**.
- 3 WARNs, all pre-existing and untouched by this spec:
  `ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28`,
  `ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25`,
  `skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38`.
- Cyclomatic ≤6 per function holds (`fails` empty across the tree).
- `shellcheck --severity=warning` on the three spec scripts → exit 0, no output
  (round-2 evidence in `25-verification.md`).
- Design-principles gate (round 1, carried forward): exit 0, **0 FAIL,
  60 WARN**. The two new WARNs on `scripts/agent-test-summary.sh:45` and
  `scripts/test-run-reuse.sh:32` are false positives per the Verifier.

## Final test status (one final time)

Full suite re-run after all stage-5a work — no code or test file was changed by
this stage, so this re-confirms the Verifier's round-2 result on the same tree.

```
ok=877  not ok=0  # SKIP=0  plan=1..877  log_lines=883  signal=0
SUMMARY: mode=run exit=0 signal=0 log_lines=883 log=/tmp/pipeline/041-mutation-runner-final-full-test-suite.log
WALL=348.53s
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)
```

Independent counts from the captured log (`grep -c`): `^ok ` → 877,
`^not ok ` → 0, `^# SKIP` → 0, TAP plan `1..877`. Same 877 as the Verifier's
round-2 run; no new or lost test.

## Evidence

### Mutation score

command: none — skipped by conformance tier (`mvp`); `docs/SPEC_PIPELINE.md` §Conformance tiers marks mutation testing `production`+, and no mutation tool is configured
exit: n/a
at: 2026-11-05T15:10:06Z

Mutation score: skipped — mvp tier
Surviving mutants: none (not applicable — no mutants generated)
Equivalent mutants: none (not applicable — no mutants generated)

Tier determination, same `mvp` project:

command: scripts/check-code-principles.sh --gates complexity --json
exit: 0
at: 2026-11-05T15:10:06Z

{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "111" }]
}

### Final test status

command: /usr/bin/time -f 'WALL=%es' scripts/agent-test-summary.sh --run /tmp/pipeline/041-mutation-runner-final-full-test-suite.log -- make test
exit: 0
at: 2026-11-05T15:04:05Z

SUMMARY: mode=run exit=0 signal=0 log_lines=883 log=/tmp/pipeline/041-mutation-runner-final-full-test-suite.log
WALL=348.53s
ok=877  not ok=0  # SKIP=0  plan=1..877
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)

### Test-run reuse check (residual WARN, reproduced)

command: scripts/test-run-reuse.sh --check specs/041-pipeline-token-savings/25-verification.md
exit: 1
at: 2026-11-05T15:04:01Z

RERUN hash-mismatch
current-hash: d93f8d7bc9db00995c213dd7cc70fdff578062061b3b4c265c6de3c3a57b05ab

The current hash equals the round-2 hash recorded by the Verifier; `--check`
still returned `RERUN` because it reads the **first**
`## Evidence: full test suite` block, which carries round 1's stale hash. See
WARN 1 below.

### Audit-trail gate

command: scripts/check-audit-trail.sh 041-pipeline-token-savings
exit: 0
at: 2026-11-05T15:10:53Z

PASS 041-pipeline-token-savings: 10-tasks.md present and non-empty
PASS 041-pipeline-token-savings: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 041-pipeline-token-savings: 25-verification.md present and non-empty
PASS 041-pipeline-token-savings: 30-report.md present and non-empty
PASS 041-pipeline-token-savings: evidence block 'scenario traceability' — command: scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-11-05T14:30:41Z
PASS 041-pipeline-token-savings: evidence block 'full test suite' — command: /usr/bin/time -f 'WALL=%es' scripts/agent-test-summary.sh --run /tmp/pipeline/041-verifier-full-test-suite.log -- make test, exit: 0, at: 2026-11-05T14:23:46Z
PASS 041-pipeline-token-savings: evidence block 'complexity gate' — command: scripts/check-code-principles.sh --gates complexity --json; shellcheck --severity=warning scripts/agent-test-summary.sh scripts/check-doc-section-refs.sh scripts/test-run-reuse.sh, exit: 0, at: 2026-11-05T14:30:45Z
PASS 041-pipeline-token-savings: evidence block 'design-principles gate' — command: scripts/check-code-principles.sh --json, exit: 0, at: 2026-11-05T14:30:43Z
PASS 041-pipeline-token-savings: evidence block 'scenario-to-behavior spot check' — command: manual — read bats assertions for AC-041-07/30/32/33/38/40/49 and executed the corresponding behavior live, exit: 1, at: 2026-11-05T14:30:46Z
✔ Audit-trail check: specs/041-pipeline-token-savings complete, verifier evidence recorded.

Note: like `test-run-reuse.sh --check`, this gate reads the **first** matching
evidence block per check, so it quotes round-1 timestamps and round-1
`spot-check` exit 1 while the round-2 verdict is PASS. It exits 0; the same
first-block limitation as WARN 1, recorded rather than fixed (out of stage-5a
scope).

### Stage read cost (residual WARN, reproduced)

command: scripts/measure-stage-read-cost.sh .
exit: 0
at: 2026-11-05T15:10:01Z

Stage read cost — baseline 50836 bytes, budget 50% (= 25418 bytes)
stage               bytes   ratio  verdict
specifier           14441   0.284  ok
ux                  23293   0.458  ok
coder               15872   0.312  ok
refactorer          14123   0.277  ok
verifier            25409   0.499  ok
mutation-runner     22631   0.445  ok
pr-opener           24906   0.489  ok
deployer            18744   0.368  ok

Every stage reads at most 50% of the unsplit document.

## Residual WARNs carried forward

1. **`test-run-reuse.sh --check` reads only the first full-suite block.** A
   re-verification appends a second `## Evidence: full test suite` block, so the
   check compares against the first (round-1) hash and always returns
   `RERUN hash-mismatch` — a redundant run, never a skipped one. Reproduced
   above: exit 1 despite the current hash matching the round-2 hash exactly.
   Fail-safe direction holds; the −1-run saving applies only to a spec's first
   verification run. Follow-up: parse the last matching block, or refresh the
   hash line in the existing block on re-run.
2. **AC-041-40/41 remain documentation-string assertions.** The mechanical half
   of AC-041-40 (a recorded hash authorizes reuse with no test command) is
   proven live in `25-verification.md`, but "no test command is executed" is
   still an agent following prose, not an executable assertion.
3. **Verifier read-cost headroom: 9 bytes.** `verifier` 25,409 B / ratio 0.499
   against the 25,418 B budget. Passing, but any growth in the verifier stage
   docs trips the budget. Reproduced above at `2026-11-05T15:10:01Z`.
4. **Design-principles 60 WARN (round 1, carried forward).** 0 FAIL; two of the
   WARNs are false positives on new spec scripts
   (`scripts/agent-test-summary.sh:45`, `scripts/test-run-reuse.sh:32`). Not
   re-run in stage 5a — no gate script changed.
5. **F1 follow-up (not applied).** `docs/changes/038-trim-agent-prompts.md` was
   edited because AC-037-03-01 forbids stale `§<moved section>` references
   anywhere under `docs/`, archive one-pagers included. Verified true by the
   Verifier. Proposed follow-up: narrow AC-037-03-01 to exclude
   `docs/changes/` archives (frozen historical records), then revert.

## Remediation record

No BLOCK occurred during stage 5a. Carried forward from
`25-verification.md` (attempt entries) and `runs.jsonl`:

| BLOCK | Gate | Phase | Resolved at attempt | Retries consumed | Evidence |
|---|---|---|---|---|---|
| 1 | `spot-check` — round-1 findings B1, B2, B3 (FAIL) | phase 1 (pre-PR) | attempt 2 — scoped re-verification PASS | 1 of max 3 | `25-verification.md` §Verdict (Attempt 1) and §Round-2 verdict (Attempt 2, phase 1); `runs.jsonl` records `loopCount=2, phase1Retries=1, phase2Retries=0` |
| — | phase 2 (post-PR CI) | — | none — no PR opened yet, so the loop has not started | 0 of max 3 | stage 5b has not run |
| — | phase 3 (deploy) | — | not reached — runs only after phase 2 is green | — | `40-deploy.md` not yet written (stage 5c) |

`25-verification.md` carries explicit attempt information (Attempt 1 / Attempt
2, phase 1), so no entry here is guessed.

## Working-tree state

Dirty, by design: this is stage 5a, pre-commit, and stage 5b owns the commits.
Every dirty path is this spec's own work — modified agent/doc/gate files named in
`10-tasks.md`, the spec's new scripts and bats tests, the spec folder itself, and
`runs.jsonl` gate telemetry. Nothing unrelated was present; nothing was stashed
or committed. This stage added only `30-report.md` (plus `/tmp` logs).

## Artifacts of this stage

- Report: `specs/041-pipeline-token-savings/30-report.md` (this file)
- Verifier source of record: `specs/041-pipeline-token-savings/25-verification.md`
- Full log: `/tmp/pipeline/041-mutation-runner-final-full-test-suite.log` (883 lines)
- Not committed, not pushed — stage 5b's job.
