# 30-report — spec 043-agent-eval-harness

- Mutation Runner run: attempt 1, phase 1
- Branch: `spec/043-agent-eval-harness`
- Verifier precondition: **PASS** (phase 1, attempt 3 — `25-verification.md` §Phase-1 verdict)
- Conformance tier: **`mvp`** — mutation testing is a recorded **skip**, not a score
- Information barrier: `specs/*/00-informal.md` was not read. This report is written
  from `25-verification.md`, the pipeline docs, and this stage's own command transcripts.
- No commit, push, tag, or PR was made. The only file written under `specs/` is this one.

## Verdict

| Item | Result |
|---|---|
| Verifier verdict (carried forward) | **PASS — phase 1, attempt 3** |
| Conformance tier | `mvp` (no `production` declaration; harness default) |
| Mutation score | **skipped — `mvp` tier** (no score fabricated) |
| Surviving mutants | **none** — no mutation engine ran, so no mutant was generated |
| Equivalent mutants | **none assessed** — nothing to classify as un-killable |
| Final test status | **GREEN** — `make test` and `make test-scripts` both exit 0, 873 `ok`, 0 `not ok`, 0 `# skip` |
| Complexity / design-principles | **PASS** — 0 FAIL, 58 WARN, none under `evals/` |
| **Stage verdict** | **GREEN** — stage 5b (PR Opener) may proceed |

## Conformance tier ruling — `mvp`

Mutation testing is a `production`-tier rule
(`docs/CONFORMANCE_TIERS.md` §Tier assignments, "Mutation testing (PiTest /
Gremlins / Stryker)"). A project declares its tier in `AGENTS_<PROJECT>.md`; this
repo has no such file and no `Conformance tier: production` declaration, so the
Makefile's own condition and the harness default both resolve to `mvp`
(`docs/SPEC_PIPELINE.md` §Stop-and-Ask decision matrix, row "Project type
ambiguous … Defer to the harness default (`mvp` tier)").

## Evidence: conformance tier

command: ls AGENTS_*.md; grep -rn "Conformance tier" AGENTS.md AGENTS_*.md Makefile docs/CONFORMANCE_TIERS.md
exit: 2
at: 2026-11-05T21:30:05Z

```
ls: cannot access 'AGENTS_*.md': No such file or directory
ls-exit=2
grep: AGENTS_*.md: No such file or directory
Makefile:147:	@if grep -q "Conformance tier: production" AGENTS.md 2>/dev/null || grep -q "Conformance tier: production" AGENTS_*.md 2>/dev/null; then \
Makefile:155:	@if grep -q "Conformance tier: production" AGENTS.md 2>/dev/null || grep -q "Conformance tier: production" AGENTS_*.md 2>/dev/null; then \
docs/CONFORMANCE_TIERS.md:20:## Conformance tier: mvp
grep-exit=2
--- makefile condition:
mvp (no production declaration)
```

`grep-exit=2` is grep's error for the non-existent `AGENTS_*.md` literal; it is not a
gate failure. `docs/CONFORMANCE_TIERS.md:20` is the documentation's fenced **example**,
not a declaration for this repo, and the Makefile does not read that file. The
design-principles gate independently reports the same tier: `Checking design
principles in: . (tier: mvp)` (evidence below).

## Mutation score: skipped — `mvp` tier

Per the stage rules, an `mvp` project skips mutation testing entirely. No tool was
run, installed, or added as a dependency. The changed production surface
(`evals/lib/*.sh`, `evals/runner/*.sh`, `evals/probes/**`,
`scripts/check-agent-evals.sh`) is bash-only, and the repo configures no shell
mutation engine — so even a hypothetical production tier would have no
PiTest/Gremlins/Stryker target here. That tooling gap is reported, not used to block,
exactly as the stage file permits for missing Go mutation tooling.

## Evidence: mutation score

command: make mutation
exit: 0
at: 2026-11-05T21:14:54Z

```
skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)
```

**Mutation score: skipped — `mvp` tier.** No mutation engine ran and no numeric
score is asserted.

## Evidence: mutation tooling availability (secondary)

command: for t in gremlins go-mutesting stryker mutmut cargo-mutants pitest; do command -v "$t" || echo "$t: not installed"; done; npx --no-install stryker --version
exit: 0
at: 2026-11-05T21:30:32Z

```
gremlins: not installed
go-mutesting: not installed
stryker: not installed
mutmut: not installed
cargo-mutants: not installed
pitest: not installed
npx-stryker-exit=1
```

### Surviving mutants and the tests that kill them

**None.** With the mutation run skipped by tier, zero mutants were generated, so
there are no survivors and no mutation-kill tests to add. The slot for
"surviving mutants and the tests that kill them" is therefore an explicit empty
set, not an unrecorded omission.

Because no mutation score measures assertion strength, the strongest proxies the
`mvp` tier does require were run instead, and both are green:

- `scripts/check-bats-assertions.sh` — 83 bats files, no vacuous assertions
  (catches bare `true`, `|| true`, status-less `run`).
- `scripts/check-scenario-traceability.sh` — all 63 live `AC-043-*` scenarios
  traced to a real test, exit 0.

### Equivalent mutants

**None assessed.** No mutation engine ran, so no mutant exists to judge equivalent
or un-killable. This is an empty list because mutation testing did not apply — not
because every mutant was killed.

## Complexity summary (carried from the Refactorer via the Verifier)

The Refactorer writes no report artifact by design
(`docs/spec-pipeline/audit-contract.md` §What each stage leaves behind); the
Verifier re-ran the structure gates and recorded the measurements. Carried into
this report unchanged, and independently re-run here:

| Measurement | Result |
|---|---|
| Tier | `mvp` |
| Complexity / KISS | PASS — no violation in the changed surface |
| Design principles | 0 FAIL, 58 WARN |
| WARNs inside `evals/` | 0 — every WARN is a pre-existing file (`ci/templates/`, `skills/hallmark/`, `scripts/*`) |
| Property tests | skipped at `mvp` (`docs/CONFORMANCE_TIERS.md`: property testing is `production`) |

No complexity or design-principles FAIL exists, so there is nothing to fix and no
threshold was touched.

## Gate results

### Evidence: full test suite (`make test`)

command: make test
exit: 0
at: 2026-11-05T21:15:02Z

```
Checking bats assertions are not vacuous...
PASS check-bats-assertions: 83 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
...
ok 288 AC-043-53: the hermetic suite grades positives and negatives without recording
ok 289 AC-043-54: broken variant 1 is caught by no-tasks-file
ok 290 AC-043-55: broken variant 2 is caught by no-commit or no-pr
ok 291 AC-043-56: broken variant 3 is caught by no-commit
...
ok 873 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)
EXIT=0
END 2026-11-05T21:22:10Z
```

Measured counts from the same transcript: `ok` = 873, `not ok` = 0, `# skip` = 0,
plan = `1..873`, unique `AC-043-*` ids = 63.

### Evidence: full test suite (`make test-scripts`, final run)

command: make test-scripts
exit: 0
at: 2026-11-05T21:22:15Z

```
Checking bats assertions are not vacuous...
PASS check-bats-assertions: 83 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
...
ok 873 unit: successful under-cap call writes no reason line at all
EXIT=0
END 2026-11-05T21:29:22Z
```

Measured counts: `ok` = 873, `not ok` = 0, `# skip` = 0, plan = `1..873`. This is
the **final** suite run of the stage; no test or production file changed after it.

### Evidence: complexity and design-principles gate

command: bash scripts/check-code-principles.sh
exit: 0
at: 2026-11-05T21:29:29Z

```
Checking design principles in: . (tier: mvp)

PASS Complexity/KISS (java): no violations found
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25
...
✔ Design-principles check: 0 FAIL(s), 58 WARN(s).
  WARNs are review hints — verify each before merging.
```

Counts with ANSI escapes stripped: `FAIL` = 0, `WARN` = 58. `grep -E
'^(FAIL|WARN).*evals/'` returns nothing. Every WARN is a pre-existing file; none is
in the spec-043 changed surface. WARNs are recorded, not treated as a stop.

### Evidence: agent-eval gate self-test

command: bash scripts/check-agent-evals.sh --self-test
exit: 0
at: 2026-11-05T21:29:38Z

```
self-test: missing task entry ok
self-test: task cannot fail ok
self-test: missing ADR row ok
self-test: missing self-CI step ok
```

### Evidence: proxy gates at `mvp` tier

command: bash scripts/check-scenario-traceability.sh
exit: 0
at: 2026-11-05T21:29:46Z

```
63 PASS AC-043-* lines
✔ Scenario traceability check: every scenario traced, every reference resolves.
```

command: bash scripts/check-bats-assertions.sh
exit: 0
at: 2026-11-05T21:29:38Z

```
PASS check-bats-assertions: 83 bats file(s), no vacuous assertions.
```

command: bash scripts/check-remediation-budget.sh
exit: 0
at: 2026-11-05T21:30:19Z

```
PASS AC-008-01/AC-008-04: .github/workflows/self-ci.yml runs check-remediation-budget.sh
PASS AC-008-04: scripts/check-remediation-budget.sh exists and is executable

✔ Remediation budget check: every check passed.
```

command: make validate-all
exit: 0
at: 2026-11-05T21:30:23Z

```
All cross-references valid.
Checking all docs/ cross-refs exist...
All docs/ cross-refs valid.
Checking SKILL.md files...
[WARN] skills/hallmark/SKILL.md — Body has 562 lines (>500 limit recommended by Agent Skills spec; move details to references/)

All SKILL.md files valid (1 warning(s)).
All validations passed.
```

The `skills/hallmark/SKILL.md` warning is pre-existing and outside spec-043.

## Final test status

**GREEN.** The full suite was re-run twice after the Verifier's PASS —
`make test` (exit 0, 873 `ok`, 0 `not ok`, 0 `# skip`, `1..873`) and
`make test-scripts` (exit 0, identical counts). The last run is the stage's final
test status. No tests were added or modified by this stage, so the Verifier's suite
result is re-confirmed, not merely repeated.

## Residual finding carried from the Verifier — `core.fsmonitor`

The Verifier's only phase-1 residual is the host-verifier trust boundary
(`25-verification.md` §Residual limitations item 1): the agent controls the mounted
workspace, including the scratch repository's shared `.git/config`, so a planted
`core.fsmonitor` executes on the **host** if a host-side verifier runs
`git status`/`git diff` against that workspace. The shipped three verifiers use
`rev-list`, `ls-remote`, and `symbolic-ref`, none of which triggers the hook, so the
residual is latent and unreachable by the delivered task set.

Status in this stage: **not made reachable.** This stage added no tests (mutation is
skipped by tier), so no new verifier invocation against an agent-controlled
workspace was introduced. The `git status`/`git diff` commands used for the
working-tree note below ran against the source worktree, not an eval workspace. If a
future mutation-kill test needs `git status`/`git diff` on `$EVAL_WORKSPACE`, the
stage stop condition applies: stop and report, and require the Verifier's documented
follow-up (grade a copy, run the verifier in the same container, or force
`-c core.fsmonitor=` / `-c core.hooksPath=` on every host-side git command).

## Working-tree note

`git status --porcelain` reports 17 entries. Every one belongs to this spec's own
change set — the 6 tracked files the Verifier recorded (`.github/workflows/self-ci.yml`,
`Makefile`, `agents/spec-specifier.md`, `docs/adr/README.md`,
`docs/spec-pipeline/specifier.md`, `runs.jsonl`) plus the untracked spec deliverables
(`docs/adr/0022-agent-eval-harness.md`, `evals/`, `scripts/check-agent-evals.sh`, the
six `scripts/tests/ac-043-*.bats` files, and `specs/`). There is no unrelated dirt.
Nothing was stashed, committed, or reverted. `runs.jsonl` still shows exactly the
three Verifier telemetry insertions; this stage's runs added none.

## Remediation record

Carried from `25-verification.md`'s attempt entries; no phase or attempt was guessed.

| Phase | Attempt | Outcome | What happened |
|---|---|---|---|
| Phase 1 | 1 | BLOCK | `unaccounted` + `push-isolation`: a probe could reach the real origin and still score `REWARD=1`; `remote.eval` leaked into the source config |
| Phase 1 | 2 | BLOCK | Remaining routes: ancestor `/proc` discovery + origin push; snapshot missed gitignored files, `.git/hooks`, `.git/info/exclude` |
| Phase 1 | 3 | **PASS** | Docker boundary closed the discovery/egress channel; snapshot hardened; five standard checks green |
| Phase 2 | — | **none** | No post-PR CI loop has run yet (PR not opened); `SPEC_PHASE2_RETRIES=0` |

- Phase-1 BLOCKs were **resolved at attempt 3** after two remediation cycles
  (`SPEC_LOOP_COUNT=2`, `SPEC_PHASE1_RETRIES=2`), within the max-3 budget.
- Phase-2 BLOCKs: **none** (the stage-5b PR has not been opened).
- **This stage: no BLOCK.** All commands exited 0 on their first run; nothing was
  re-run to chase a failure, and no gate or threshold was changed.

## Final verdict

**GREEN.** The Verifier's PASS was honored as the precondition. Conformance tier is
`mvp`, so mutation testing is a recorded skip with no fabricated score and no
surviving/equivalent-mutant list (none exist without a run). The strongest `mvp`
quality proxies — the full 873-test suite, traceability, no-vacuous-assertion
checking, design principles, agent-eval self-test, remediation-budget check, and
`validate-all` — all exit 0. Final test status: green. Stage 5a is complete; the PR
Opener (stage 5b) may proceed.

## PR

PR: https://github.com/RexiAI/my-engineering-standards/pull/121
Commit count: 12
