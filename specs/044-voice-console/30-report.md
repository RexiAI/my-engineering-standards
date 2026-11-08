# Report — Voice console (spec 044)

Stage: 5a, Mutation Runner. Pipeline mode: `full`
(`specs/044-voice-console/45-decisions.md`: classifier chose `full`, 61 named
paths including `**/*golangci*.yml` outside the lite surface). Conformance tier:
`mvp`.

Precondition satisfied: `specs/044-voice-console/25-verification.md` exists and
its verdict is **PASS**. No mutation-killing tests were written — at `mvp` tier
the mutation gate does not run, so the worktree is the tree the Verifier ran
against. No commit, no push, no production-code edit was made.

`specs/044-voice-console/00-informal.md` was **not** read (information barrier).

## Verdict

**GREEN** — nothing blocked. Mutation testing is skipped by tier, not by
failure; the final full-suite status is the Verifier's green run, reused on an
exact worktree-hash match.

| # | Item | Result |
|---|---|---|
| 1 | Verifier verdict (carried forward) | **PASS** — 5/5 runnable checks exit 0, 0 FAIL findings |
| 2 | Mutation score | **skipped — mvp tier** (production-tier gate) |
| 3 | Equivalent mutants | none — no mutants were generated or evaluated |
| 4 | Complexity summary (carried from Refactorer) | 7 CC violations → 0; voice DRY 6 → 0; design gate re-run by Verifier: exit 0, **0 FAIL / 67 WARN** |
| 5 | Final test status (full suite, one final time) | green — reused from `25-verification.md` on `REUSE 353be28a…22f75` (1195 `ok`, 0 `not ok`, 0 `skip`) |
| 6 | Remediation record | none — no BLOCK occurred |
| 7 | Flags carried to the Architect | 4 (recorded verbatim below; not gate failures, not fixed here) |

## Mutation testing — skipped, tier rule

`docs/SPEC_PIPELINE.md §Stages` places stage 5a after the Verifier;
`docs/spec-pipeline/mutation-runner.md` and `docs/spec-pipeline/coder.md
§Conformance tiers` scope mutation testing to `production` tier and above. This
spec declares `mvp`, so the mutation *test* is skipped while the Architect role
still runs (this report).

No private mutation tool was invented for the `.mjs` / Python surface. The repo
has no Stryker config (`package.json`, `.eslintrc*`, `eslint.config.*` absent),
no PiTest setup, and no Go module in this lane; `scripts/check-code-principles.sh`
discovers node files by `*.ts|*.tsx|*.js|*.jsx` only (script line 442), so the
`.mjs` modules are outside every mutation lane this repo wires. That is a skip
by tier and by absent tooling — not a failure, and nothing to block on.

## Complexity summary — carried from the Refactorer

Carried from the orchestrator's relay of stage 3 (the Refactorer leaves no
artifact by design; the Verifier re-records the gates). Not re-measured by this
stage — the numbers below are the stage-3 before/after, and the "after" column
was independently re-run by the Verifier:

| Measure | Before (Refactorer entry) | After (Refactorer exit) | Verifier re-check |
|---|---|---|---|
| Cyclomatic-complexity violations in the voice modules | 7 | **0** | design gate exit 0, 0 FAIL |
| DRY duplication findings in the voice modules | 6 | **0** | design gate exit 0, 0 FAIL |
| `scripts/check-code-principles.sh` aggregate | — | — | exit 0, **0 FAIL / 67 WARN** |

The 67 WARNs are review hints, not stops (`docs/SPEC_PIPELINE.md §Stop-and-Ask
decision matrix`: design-gate WARN → record and flag). Five of them are in this
spec's `scripts/voice/tts-worker.py` (Naming: more than three parameters); the
other 62 are pre-existing and untouched. Scope caveat carried verbatim from
`25-verification.md`: no new `.mjs` file is analysed by that gate — the `.mjs`
extension is outside its discovery set — so complexity evidence for those
modules is `node --check` (17/17 files parse) plus the design-principles run.

Property tests: `skipped (project tier is mvp — production+ required)`, matching
the declared tier.

## Equivalent mutants

**None.** At `mvp` tier no mutation run happened, so no mutant was produced,
killed, or survived; there is nothing to classify as equivalent. No mutant is
being excused.

## Flagged to the Architect (carried from `25-verification.md` §Flagged to the Architect, verbatim)

These are check-5 review findings, **not** gate failures. They were not fixed
here (this stage writes tests and a report, not production code) and they do not
block the run.

1. **[HIGH — unaccounted behavior]** `scripts/voice/converse.mjs:11,80` —
   `const REPLY_TIMEOUT_MS = 1500;` and
   `withTimeout(state.collector.nextTurn(), REPLY_TIMEOUT_MS, [])`. No task and no
   scenario specifies a reply deadline; the 1.5 s bound is local invention. When
   a real assistant turn takes longer than 1.5 s to emit `idle`/text, the turn
   silently speaks nothing and writes no `spoken`/`deferred`/`skipped` record —
   an operator hears dead air with no ledger trace. `AC-044-11-01`/`-04` cannot
   catch it: `scripts/tests/voice-fake-server.mjs` answers instantly. Either the
   spec gains a latency scenario or the bound becomes configurable and recorded.
2. **[MEDIUM — spec-mandated but vacuous]** `scripts/voice/control.mjs:55,60,65` —
   each outbound reply is preceded by
   `authorize({ tool: "read", command: null, paths: [], repoRoot: process.cwd() })`.
   A `read` intent can never be blocked (`policy.mjs:241-244` returns
   `blocked:false` for `READ_TOOLS`), so these three calls enforce nothing. They
   exist to satisfy `AC-044-03-03` literally ("every call … immediately preceded
   by a `guard.authorize` call"). The real policy decision is
   `authorize(event.intent)` at `control.mjs:157`. The scenario verifies shape,
   not effect; a future edit could delete the effective call at line 157 and keep
   the test green.
3. **[LOW — spec gap]** `scripts/voice/tts-worker.py:87-95` — `run_engine` reports
   `missing-runtime` for `--engine pocket-tts` unconditionally; `available("pocket_tts")`
   is only consulted by `--self-check`. No scenario covers the engine being
   present (`AC-044-04-07` covers absent only), so nothing is violated, but the
   worker can never synthesize with Pocket TTS even when installed. Follow-up
   spec if that engine is expected to work.
4. **[TRIVIAL — dead code]** `scripts/voice/install.mjs:6` imports `basename` and
   never uses it. YAGNI/DRY hint only.

## Remediation record

**none** — no BLOCK occurred during this run.

Basis, carried forward and not guessed: `25-verification.md` line 9 records
`Stage: 4, Verifier. Attempt: **1**, phase **1** (first full run, not a
re-verification)`. There is no re-verification attempt entry and no BLOCK line in
`25-verification.md`, so no phase-1 or phase-2 remediation was consumed. Phase 3
(deploy verification) is out of scope for this stage. This stage itself produced
no BLOCK.

## Evidence: mutation score

command: for f in AGENTS_*.md; do t=$(grep -oE 'Conformance tier: (mvp|production|multi-service)' "$f" 2>/dev/null | head -1 | awk '{print $3}'); if [ -n "$t" ]; then echo "declared: $t"; exit 0; fi; done; echo "tier: mvp (no AGENTS_*.md declaration; scripts/check-code-principles.sh:440 default)"
exit: 0
at: 2026-11-08T13:48:07Z

```
tier: mvp (no AGENTS_*.md declaration; scripts/check-code-principles.sh:440 default)
```

Mutation score: skipped — mvp tier

Reason: mutation testing is a `production`-tier gate
(`docs/spec-pipeline/coder.md §Conformance tiers`,
`docs/spec-pipeline/mutation-runner.md`). No mutation tool is configured for this
repo's `.mjs` / Python surface, and inventing one is out of scope at `mvp`.
No mutants generated, none surviving, none equivalent.

## Evidence: test-run reuse decision

command: scripts/test-run-reuse.sh --check specs/044-voice-console/25-verification.md
exit: 0
at: 2026-11-08T13:48:18Z

```
REUSE 353be28a4e8f3ce27f4b93b0f4e27de800f62d47e64df98daad7460186e22f75
```

Post-check `scripts/test-run-reuse.sh --print-hash`:
`353be28a4e8f3ce27f4b93b0f4e27de800f62d47e64df98daad7460186e22f75` — identical,
so the tree is the one the Verifier ran against. Exit 0 means **reuse**: no test
command was executed by this stage. (`git status --porcelain` is likewise
unchanged apart from this report and the excluded `runs.jsonl`.)

## Evidence: final test status

command: scripts/agent-test-summary.sh --run /tmp/opencode/pipeline/044-verifier-suite.log -- env BATS_JOBS=8 make test-scripts
exit: 0
at: 2026-11-08T13:42:36Z
reused-from: 25-verification.md §Evidence: full test suite (test-run hash 353be28a4e8f3ce27f4b93b0f4e27de800f62d47e64df98daad7460186e22f75)

```
SUMMARY: mode=run exit=0 signal=0 log_lines=1300 log=/tmp/opencode/pipeline/044-verifier-suite.log
```

The `command:` / `exit:` / `at:` values are the Verifier's, copied verbatim —
that run did happen, then, on this exact tree. Independent counts over the full
log (from `25-verification.md`): 1195 `ok`, 0 `not ok`, 0 `skip`, 133 of them
`AC-044-*`. No test was skipped (a skipped test is a failure). Stage 5a added no
tests, so there is no new code the Verifier's run could have missed.

Final test status: **green** (reused, not re-run).

## Notes

- Nothing was committed, pushed, or opened as a PR; that is stage 5b's job.
- No production code, gate config, threshold, or acceptance scenario was edited.
- The only artifact written by this stage is this report.

## PR

PR: https://github.com/RexiAI/my-engineering-standards/pull/123
Commits: 16 (one conventional commit per task in `10-tasks.md`, counted at PR
open; this record commit is the 17th and is not included). Branch
`spec/044-voice-console`, draft, base `main`. Stage 5d (archive) has not run —
`specs/044-voice-console/` is still present for stage 5c's deploy verification.
