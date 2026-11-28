# Report — spec 045: PR size gate and review-gated auto-merge

- **Stage**: 5a (Mutation Runner)
- **Date**: 2026-11-28
- **Branch / HEAD**: `spec/045-pr-size-gate-and-auto-merge` @ `e0cf798` (human-authorized
  commit; not pushed). Working tree carries only ` M runs.jsonl`, ` M 25-verification.md`
  (the Verifier's attempt-2 record, written after the commit) and `?? .playwright-mcp/`.
- **Pipeline mode**: `full` (`45-decisions.md`; its single entry resolves the mode, not an
  autopilot ask)
- **Verifier verdict (carried forward)**: **PASS** — `25-verification.md`
  §Re-verification — attempt 2, phase 1
- **Overall verdict**: **GREEN**

Autopilot: false
Autopilot decisions: 0

This stage wrote `specs/045-pr-size-gate-and-auto-merge/30-report.md` only. It did not
commit, push, or open a PR, and it did not touch `.playwright-mcp/`.

## Verdict

| Gate | Result | Evidence |
|---|---|---|
| Verifier verdict (precondition) | **PASS** — attempt 2, phase 1 | `25-verification.md` §Re-verification |
| Mutation testing | **skipped — `mvp` tier** | §Evidence: mutation score |
| Complexity (carried from the Refactorer) | exit 0 — 0 FAIL, 3 WARN (all pre-existing, outside the change surface) | §Evidence: complexity gate |
| Design principles | exit 0 — 0 FAIL, 70 WARN (1 in new code, advisory) | §Evidence: design-principles gate |
| Final test suite | **exit 0** — 1347 ok, 0 not ok, 1 skip | §Evidence: final test status |

GREEN: the mutation gate does not apply at this tier, the design gates show no FAIL, and
the final full suite ran green (exit 0) on the tree whose fingerprint is recorded in
§Evidence: final test status — identical before and after that run.

## Mutation testing — skipped, and why

Mutation testing is a `production`-tier gate (`docs/spec-pipeline/coder.md`
§Conformance tiers, as cited by this stage's rules). This repository is at `mvp` tier:
`scripts/check-code-principles.sh` auto-detects the tier and there is no `AGENTS_*.md`
carrying a `Conformance tier:` declaration, so the documented default applies. The tier
is not a judgement call and was not overridden.

A second, independent reason points the same way: the change surface has no mutation
target. The commit is bash, YAML, and Markdown — no JS/TS, Java, or Go project exists at
the repository root, so there is no Stryker/PiTest/go-mutesting subject. Probe (verbatim):

```
$ ls package.json pom.xml go.mod Cargo.toml build.gradle stryker.conf.json stryker.conf.js
ls: cannot access 'package.json': No such file or directory
ls: cannot access 'pom.xml': No such file or directory
ls: cannot access 'go.mod': No such file or directory
ls: cannot access 'Cargo.toml': No such file or directory
ls: cannot access 'build.gradle': No such file or directory
ls: cannot access 'stryker.conf.json': No such file or directory
ls: cannot access 'stryker.conf.js': No such file or directory
exit=2          (run 2026-11-28T18:21:24Z)
```

`scripts/run-mutation.sh` refuses that state by design: it `die`s with
`no stryker config in <dir> — not a Stryker project` and exit code 3. Running it would
have produced a tooling-failure line, not a score; the stage rule is to record the skip
and stop, so it was not run.

### Mutation score

**Not computed.** The score is `skipped — mvp tier`. It is therefore neither a *scoped*
nor a *whole-tree* score, and it is not presented as either. No survivors exist to kill
because no mutants were generated, so no mutation-killing test was written — adding tests
here would be unrelated coverage, not a mutation kill, and the stage rule forbids widening
scope to look busy.

### Equivalent mutants

**None.** This is a statement about the run, not a claim about the codebase: no mutation
run happened, so no mutants were generated, survived, or needed to be classified as
un-killable. There is no equivalent-mutant list to justify because there was no survivor
set.

## Complexity summary carried from the Refactorer

The Refactorer leaves no report artifact by design; its gates are re-recorded by the
Verifier in `25-verification.md` §Evidence: complexity gate, and this stage re-ran them to
confirm the tree still holds (both read-only, both exit 0):

- **Complexity/KISS**: 0 FAIL, 3 WARN — none in this spec's change surface:
  - `Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28`
  - `Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25`
  - `Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38`
- **Real linter (carried from the Verifier, not re-run)**: `shellcheck --severity=warning`
  over the six changed scripts produced no output, exit 0. An unfiltered run of the same
  six exits 1 on four info-level notes only: three `SC1091` (the repo-wide dynamic
  `source …/pr-gate-lib.sh` pattern) and one `SC2016` (backticks in a posted comment are
  intentional literal text). Neither class is a finding at the configured severity.
- The changed surface is bash/YAML/Markdown, so `golangci-lint`/`pmd`/`eslint` do not apply.

## Final test suite — the mechanical decision

The decision procedure is `docs/spec-pipeline/mutation-runner.md` §Full suite, one final
time. It was followed mechanically, not improvised:

1. `bash scripts/test-run-reuse.sh --check specs/045-pr-size-gate-and-auto-merge/25-verification.md`
   → **exit 1, `RERUN exit-nonzero`** at `2026-11-28T17:45:24Z`. This is the failure mode
   the Verifier predicted: the helper reads the first `## Evidence: full test suite` block,
   which is attempt 1's (`exit: 2`), so reuse is denied even though the current tree hash
   (`51ef233a…`) equals attempt 2's recorded hash. The fail-safe direction holds — a
   redundant run, never a skipped one — so the branch taken was **run the suite myself**,
   with no `reused-from:` line.
2. **Run 1** (`2026-11-28T17:45:27Z` → `2026-11-28T18:03:16Z`, exit 2) was **red**:
   1345 ok, 2 not ok, 1 skip. The two failures are `AC-044-10-06` (SIGINT exits cleanly)
   and `AC-044-13-06` (the governance row is present and T0) — both in
   `scripts/tests/voice-console.bats`, i.e. spec 044's suite, which this spec does not
   touch (`git diff --name-only 25924a1..e0cf798` contains no voice file; that file last
   changed in `5911249 feat(voice): voice console (spec 044)`).
3. **Diagnosis before any second run**, so the re-run is a characterisation of a suspected
   flake and not a retry-until-green:
   - both failing tests pass **in isolation** (`bats --tap --filter …` exit 0 each, twice);
   - the whole `voice-console.bats` file re-run reproduces `AC-044-10-06` (`not ok 86`,
     132 ok / 1 not ok of 133) but **not** `AC-044-13-06`, and `scripts/check-governance.sh`
     passes standalone (exit 0) — so `AC-044-10-06` is an order/load-sensitive SIGINT
     timing test, and `AC-044-13-06` was a one-off;
   - every test in this spec's five bats files was `ok` in the red run too — `pr-size-gate`
     31, `pr-size-gate-deliverables` 52, `pr-review-verdict` 15,
     `pr-automerge-eligibility` 25, `pr-automerge-notify` 12 (135 `@test` blocks, 103 of
     them carrying an `AC-045-…` ID in the title, the rest `unit —` cases in the same
     files); `grep '^not ok'` over the run-1 log returns exactly the two spec-044 lines
     quoted below.
4. **Run 2** — one second full run, the flake re-check the repo already documents for this
   situation (spec 033, "run twice, per flake re-check") — `2026-11-28T18:08:32Z` →
   `2026-11-28T18:19:46Z`, **exit 0**: 1347 ok, 0 not ok, 1 skip. The pre-run and post-run
   hashes are both `51ef233a22ba47cf9497801e11f4f7500ff92cf9d6b23f9dbb1b4fce706cd0cf`, so
   no `tree-changed-during-run` finding applies.
5. **Attribution.** The red run is a pre-existing, pre-044-merge flake in another spec's
   timing test plus one unreproduced one-off; it is not caused by spec 045, whose entire
   test surface is green in both runs. Per the Stop-and-Ask matrix ("Out-of-scope finding →
   record it; do not fix; propose a follow-up spec") it is recorded in
   §Findings recorded, not fixed and **not** fixed here. The suite is nonetheless shown
   green (exit 0) by run 2 on the tree whose fingerprint the final-status row records, and
   run 1 is kept verbatim below it rather than discarded.

The single skip in both runs is the pre-existing branch guard `AC-041-53` ("scoped to spec
041's branch"), the test's own scope condition; a skip is never a pass, and it is recorded
as unchanged by this spec.

## Evidence: mutation score

command: bash scripts/check-code-principles.sh --json
exit: 0
at: 2026-11-28T18:19:55Z

```
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests", "comments", "naming", "null-discipline"],
  "fails": [],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, … ]
}
```

(excerpt: `tier`, `gates`, `fails` verbatim; the `warns` array's 70 entries elided after the
first.)

Mutation score: **skipped — `mvp` tier** (a `production`+ gate; `mvp` is the auto-detected
default and no `AGENTS_*.md` overrides it). Second, independent reason on the same machine:
no Stryker/PiTest/go-mutesting project at the repository root, so `scripts/run-mutation.sh`
would exit 3 with `no stryker config in <dir> — not a Stryker project`.

## Evidence: final test status

command: bash scripts/agent-test-summary.sh --run /tmp/opencode/pipeline/045-mutation-runner-suite-run2.log -- make test-scripts
exit: 0
at: 2026-11-28T18:19:46Z
Test-run hash: 51ef233a22ba47cf9497801e11f4f7500ff92cf9d6b23f9dbb1b4fce706cd0cf

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 109 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..1347
ok 339 AC-041-53 — no gate script or threshold changed # skip AC-041-53 is scoped to spec 041's branch (current: spec/045-pr-size-gate-and-auto-merge)
...
ok 1346 AC-044-16-07: the ADR is recorded
ok 1347 AC-044-16-08: repo gates stay green and no weights are tracked
SUMMARY: mode=run exit=0 signal=0 log_lines=1352 log=/tmp/opencode/pipeline/045-mutation-runner-suite-run2.log
```

Plan: 1..1347 — **1347 ok, 0 not ok, 1 skip** (the skip is annotated above). Run window
`2026-11-28T18:08:32Z` → `2026-11-28T18:19:46Z`; pre-run hash (18:08:32Z) and post-run hash
(18:19:49Z) are identical, so no `tree-changed-during-run` finding applies. This is the
authoritative final-status row: the command above is the run that produced it.

Provenance note: `30-report.md` is untracked and is **not** in the reuse helper's exclusion
set, so writing this file after the run necessarily moves the worktree fingerprint. The
hash recorded above is the post-run hash taken at 18:19:49Z, before this file existed —
a later `--check` against this report would legitimately report `RERUN hash-mismatch` for
that reason alone, and the run above is the evidence.

## Evidence: suite run 1 (flake-recheck baseline — superseded by the block above)

command: bash scripts/agent-test-summary.sh --run /tmp/opencode/pipeline/045-mutation-runner-suite.log -- make test-scripts
exit: 2
at: 2026-11-28T18:03:16Z
Test-run hash: 51ef233a22ba47cf9497801e11f4f7500ff92cf9d6b23f9dbb1b4fce706cd0cf

```
not ok 1300 AC-044-10-06: SIGINT exits cleanly, twice forces exit
# (in test file scripts/tests/voice-console.bats, line 1430)
#   `[ "$rc" -eq 0 ]' failed
not ok 1323 AC-044-13-06: the governance row is present and T0
# (in test file scripts/tests/voice-console.bats, line 1779)
#   `[ "$status" -eq 0 ]' failed
SUMMARY: mode=run exit=2 signal=2 log_lines=1357 log=/tmp/opencode/pipeline/045-mutation-runner-suite.log
```

Plan: 1..1347 — 1345 ok, 2 not ok, 1 skip. Pre-run hash (17:45:27Z) and post-run hash
(18:03:19Z) are both `51ef233a…`, so the tree did not change during the run and the
difference from run 2 is not a code difference. Reproduction and isolation evidence:

```
$ bats --tap scripts/tests/voice-console.bats          # whole file, finished 2026-11-28T18:08:18Z
132 ok, 1 not ok of 133 — only "not ok 86 AC-044-10-06: SIGINT exits cleanly, twice forces exit"
exit 1

$ bats --tap --filter 'AC-044-10-06' scripts/tests/voice-console.bats
1..1
ok 1 AC-044-10-06: SIGINT exits cleanly, twice forces exit      exit 0

$ bats --tap --filter 'AC-044-13-06' scripts/tests/voice-console.bats
1..1
ok 1 AC-044-13-06: the governance row is present and T0         exit 0

$ bash scripts/check-governance.sh
PASS AC-010-06-02 — compliant repo passes all checks (exit 0)
✔ Governance check: every governance requirement verified.      exit 0
```

(ANSI colour escapes elided in the isolation transcript; the TAP lines are verbatim.)

(The isolation commands ran 2026-11-28T18:19:59Z → 18:20:03Z; the whole-file run's
timestamp is its TAP file's completion time.)

## Evidence: complexity gate

command: bash scripts/check-code-principles.sh --gates complexity
exit: 0
at: 2026-11-28T18:20:16Z

```
PASS Complexity/KISS (java): no violations found
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25
WARN Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38
PASS Complexity/KISS (python): no violations found

---------------------------------------------
✔ Design-principles check (gates: complexity): 0 FAIL(s), 3 WARN(s).
  WARNs are review hints — verify each before merging.
```

(ANSI colour escapes elided; every other character is the run's own output.)

## Evidence: design-principles gate

command: bash scripts/check-code-principles.sh
exit: 0
at: 2026-11-28T18:20:16Z

```
✔ Design-principles check: 0 FAIL(s), 70 WARN(s).
  WARNs are review hints — verify each before merging.
```

(ANSI colour escapes elided.) Full log: `/tmp/opencode/pipeline/045-mut-principles.log`.
The JSON-mode excerpt in §Evidence: mutation score is the same run's `--json` shape: `tier`
and `gates` transcribed, the 70-element `warns` array elided. One WARN is in code this spec
introduces and must be seen by the reviewer:

```
WARN Comments: commented-out code (./scripts/pr-size-gate.sh:25)
```

Reading: it is a false positive of the "commented-out code" heuristic — line 25 is
`#   --format text|json       output shape (default: text)`, one line of the script's
`# Usage:` block whose option lines begin with `--`. Content is correct and required by
the AC-045-02 scenarios; the heuristic cannot tell a usage block from a commented call.
Advisory only (WARN, not FAIL), so per the Stop-and-Ask matrix ("Design gate WARN (not
FAIL) → record; do not stop") it is recorded here and neither the comment nor the gate was
touched. The other 69 WARNs are pre-existing.

## Findings recorded, not fixed

1. **Pre-existing flake, foreign spec.** `AC-044-10-06` (`scripts/tests/voice-console.bats:1411-1450`)
   is order/load-sensitive: it fails inside a full-file/full-suite run and passes in
   isolation, on an unchanged tree hash, and failed identically in both of this stage's
   order-dependent observations. It belongs to spec 044 and no spec-045 line touches it.
   Recorded, not fixed (out of scope). Proposed follow-up: a spec that makes the SIGINT
   assertions wait on an observable ledger record instead of a fixed 0.3 s sleep.
2. **One-off failure.** `AC-044-13-06` failed once in run 1 only; `check-governance.sh`
   exits 0 standalone and in the whole-file run, and the test is green in run 2. No cause
   reproduced; recorded, not fixed.
3. **Design WARN in new code** — `scripts/pr-size-gate.sh:25`, analysed above. Advisory.
4. **`?? .playwright-mcp/`** (pre-existing, unrelated, 7 files) is still untracked. It must
   not be swept into the PR by `git add -A`; this stage does not touch it, and this report
   is the only file it wrote.
5. **Workflow pin risk (phase 2, carried forward).** The callers pin
   `@21046d96796467f8238d6d613ce3a552bf3fced0`, which predates this spec's reusable
   workflows, so the callers cannot resolve them until the pin is bumped after merge. This
   is Task 11's deliberate design, but the PR Opener and the phase-2 CI loop should expect
   it.
6. **One skip** — `AC-041-53`, the pre-existing spec-041 branch guard. A skip is not a
   pass; recorded as unchanged by this spec.
7. **`reused-from:` not applicable.** Reuse was denied mechanically (`RERUN exit-nonzero`),
   so the final-status row carries this stage's own `command:`/`exit:`/`at:` and the
   post-run hash, as the decision procedure requires on the re-run branch.

## Remediation record

Carried forward from `25-verification.md` §Re-verification — attempt 2; nothing in this
record is guessed or reconstructed.

| Phase | Attempt | Gate | Outcome |
|---|---|---|---|
| 1 (pre-PR loop) | 1 | `test-suite` | FAIL — 2 `not ok` (`AC-043-26`, `AC-035-36`), both from the uncommitted `agents/pr-review.md` tripping pre-existing `AC-009-02-03` |
| 1 (pre-PR loop) | 2 | `test-suite` (scoped re-verification) | **PASS** — 1347 ok, 0 not ok, 1 skip after the human-authorized commit `e0cf798` |

- The one phase-1 gate failure of this pipeline run (`test-suite`) was **resolved at attempt
  2 of max 3**; the Verifier recorded `loopCount=1`, `phase1Retries=1`, `phase2Retries=0`.
- **No BLOCK occurred during stage 5a.** The mutation gate is not applicable at this tier,
  and the final suite is green; the red intermediate run was diagnosed as a foreign flake
  and did not consume a phase-1 attempt (nothing in this spec was fixed for it, and
  re-running a gate without a fix is not counted as remediation here — it is recorded as a
  flake re-check with both runs kept).
- Phase 2 (post-PR CI) has not run yet; its counter is `0` and independent of phase 1.

## Carried forward to the PR Opener / phase 2

- `30-report.md` is GREEN → the stage-5b precondition is satisfied.
- Do not sweep `?? .playwright-mcp/`; commit `runs.jsonl` only in the PR Opener's own
  docs/archive commit, per `docs/SPEC_PIPELINE.md` §Commit and push carve-out.
- Expect the pinned-revision callers (finding 5) to be the first phase-2 signal.

## PR

PR: https://github.com/RexiAI/my-engineering-standards/pull/132
Commits: 2 — `e0cf798` (implementation, all 12 tasks + spec artifacts to
`25-verification.md` attempt 1, human-authorized single commit; see the PR body's
"Commit structure" note) and this PR-record commit (`docs(spec):`).
Opened as a **draft** on 2026-11-28; no merge, no tag, no archive yet (stage 5d
runs after stage 5c writes `40-deploy.md`).
