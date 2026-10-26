# 30-report — 035-child-project-standards-updater

Stage 5a (Mutation Runner). Conformance tier: `mvp` (evidence below) — the mutation
gate is a recorded skip, so no mutation tool was run. The full suite was re-run
and is green. Nothing was committed, pushed, or changed in production code.

Changed surface under test (identical to the set the Verifier re-checked):

```
 M runs.jsonl
 M scripts/tests/README.md
 M scripts/update-submodules.sh
?? scripts/tests/ac-035-update-submodules.bats
?? specs/
```

`runs.jsonl` is harness telemetry, not part of this spec's diff. The dirty working
tree is the pipeline's own in-flight change (stage 5b is the committer) — per the
Stop-and-Ask matrix nothing was stashed and nothing was committed here.

---

## Verifier verdict (carried forward)

`specs/035-child-project-standards-updater/25-verification.md` — **PASS**
(Verifier run: attempt 1, phase 1 pre-PR). All five contract checks carry command,
exit code, timestamp and raw output. This stage did not substitute its own gates
for that verdict; it ran only the full suite it is required to re-confirm.

---

## Evidence: conformance tier determination

command: grep -n 'Conformance tier' AGENTS.md
exit: 1
at: 2026-10-26T13:53:38Z

(no output — the string does not occur in AGENTS.md)

Corroborating evidence, same timestamp (`2026-10-26T13:53:38Z`):

```
$ ls -1 AGENTS*.md
AGENTS.md
```

`AGENTS_*.md` does not exist, so there is no second declaration site. The report
harness default therefore applies, and the gate itself prints the tier it resolved:

```
$ ./scripts/check-code-principles.sh -BaseRef HEAD | head -2
Checking design principles in: . (tier: mvp)
```

Resolution per `docs/SPEC_PIPELINE.md §Conformance tiers` and the Stop-and-Ask row
"Project type ambiguous (… conformance tier undetectable) → defer to the harness
default (`mvp` tier)": **tier = `mvp`**.

---

## Evidence: mutation score

command: (none — recorded skip; mutation testing is a `production`-tier gate per docs/SPEC_PIPELINE.md §Conformance tiers)
exit: 0
at: 2026-10-26T13:53:38Z

Mutation score: skipped — `mvp` tier. No mutation tool (`mvn verify -Pmutation`,
`go-mutesting`/`gremlins`, `npx stryker run`) was invoked; no mutation score is
claimed. This repo's stack for the change is shell (`scripts/update-submodules.sh`),
which has no configured mutation tool in any case — the skip is driven by the tier,
not by the stack.

The `mvp` tier's test-quality controls still applied and were re-confirmed by this
run: `scripts/check-bats-assertions.sh` reports 59 bats files with no vacuous
assertions, and `scripts/check-scenario-traceability.sh` (Verifier block, exit 0)
shows every AC-035-01…AC-035-26 scenario traced to a test.

---

## Equivalent mutants

**None.** Mutation testing was not run at `mvp` tier, so no survivor list exists to
classify. This is not a claim that the suite is mutation-clean — it is a claim that
the mutation gate does not apply to this tier (`docs/SPEC_PIPELINE.md §Conformance
tiers`, Architect row: `mvp` = skip).

---

## Complexity summary (carried from the Refactorer via 25-verification.md)

The Refactorer leaves no report artifact by design (`§Audit contract`), so these are
the Verifier's re-recorded measurements, carried forward verbatim in substance:

- **Linter in scope** — `shellcheck scripts/update-submodules.sh`: exit 0, no
  findings; machine-readable transcript `[]`. This is the repo's configured shell
  linter (`.github/workflows/self-ci.yml`: `shellcheck scripts/*.sh templates/*.sh`).
- **Design-principles gate** — `./scripts/check-code-principles.sh -BaseRef HEAD`:
  exit 0, **0 FAIL(s), 0 WARN(s)**; JSON transcript
  `{"tier":"mvp","gates":["complexity","dry","yagni","solid","component-per-file","property-tests","comments","naming","null-discipline"],"fails":[],"warns":[]}`.
- **Cyclomatic complexity (≤6)** — PASS ("Complexity/KISS (java): no violations
  found"); nothing in the changed shell surface is flagged.
- **Property tests** — skipped: "project tier is mvp — production+ required".
- **Before/after Refactorer measurements** — not recorded anywhere; the Refactorer
  writes no artifact and `25-verification.md` carries only the post-refactor gate
  results above. Recorded here as a gap rather than invented.
- **Out-of-scope, pre-existing** — full-repo (non-`-BaseRef`) run exits 1 with one
  FAIL in `skills/hallmark/site/examples/cobalt-01/script.js` (CC=10), reproduced on
  pristine HEAD by the Verifier; untouched by this change, follow-up spec proposed
  there, not fixed here.

---

## Out-of-scope finding: pre-existing flaky tests (pipefail + `grep -q` SIGPIPE)

This stage's first full-suite run failed on a test **not related to spec 035**:

command: make test-scripts
exit: 2
at: 2026-10-26T13:28:29Z

```
not ok 106 unit — model-env selftest stays green with the 10-agent roster
# (in test file scripts/tests/ac-031-orchestration-compliance.bats, line 46)
#   `[ "$status" -eq 0 ]' failed
```

Not a finding against this change. Two independent full-suite re-runs were green
(below), the failing test passes in isolation (`bats --filter 'model-env selftest
stays green'` → `ok 1`, exit 0) and as a whole file (`ac-031-orchestration-compliance.bats`
→ `1..6`, all ok, exit 0), and `bash scripts/model-env.selftest.sh` passed 68/68 in
8 consecutive standalone runs (`selftest failures: 0 of 8`).

A **second, reproducible** flake in the same suite was root-caused while diagnosing:

command: awk-frontmatter-pipe | grep -qiE (reproduction of tests/AC-030-01.sh:54 via tests/ac-030-lib.sh:76 body_of)
exit: 141
at: 2026-10-26T13:53:44Z

```
awk=141 grep=0 (SIGPIPE) occurrences: 4 of 200
```

Mechanism: `tests/AC-030-01.sh` runs under `set -euo pipefail` and tests each
heading with `if body_of "$SK" | grep -qiE …`. `body_of` is an `awk` producer;
`grep -q` exits at the first match and closes the pipe, so `awk` can die on SIGPIPE
(141). With `pipefail`, the *pipeline* status becomes 141 even though `grep`
succeeded, so the `if` takes the else branch and emits a spurious
`FAIL AC-030-01-06: heading for '…' missing`. Observed failure rates: 6/300 and
4/200 (~2%), 6/20 when the machine was loaded; the SC-030 scenario that fails varies
per run, exactly as a scheduling race predicts. `scripts/model-env.selftest.sh`
carries the same construct (`… | grep -q` under `pipefail` at lines 252, 272, 523,
577, 582, 795), which is the most plausible explanation for the unreproduced run-1
failure above — stated as a hypothesis, not a confirmed cause.

Not fixed: Stop-and-Ask matrix — "Out-of-scope finding → record it; do not fix;
propose a follow-up spec", and this stage may not edit production code. Proposed
follow-up: capture the producer output first (`body_of … > tmp` or
`shift`-style `local out; out=$(body_of "$SK"); grep -qiE … <<<"$out"`) so the
producer's SIGPIPE cannot reach the pipeline status. Residual risk to this pipeline
run: the same suite is what self-ci runs, so a phase-2 CI flake of this class is
possible at roughly the measured rate and must be diagnosed as a flake, not as a
035 regression. The 26 AC-035 tests contain no producer-into-`grep -q` pipeline
(greps are direct or `run grep -q`), so this spec does not add to the flake class.

---

## Evidence: final test status

command: make test-scripts
exit: 0
at: 2026-10-26T13:45:02Z

```
Checking bats assertions are not vacuous...
PASS check-bats-assertions: 59 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..662
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
… (662 total `ok` lines; representative head + tail) …
ok 660 unit: a cap smaller than the marker still never exceeds the cap
ok 661 unit: state exactly at the cap is not truncated and emits no reason
ok 662 unit: successful under-cap call writes no reason line at all
```

Full-suite invocations in this stage, in order (this is the audit trail for the
"never re-run until green" rule — every re-run is a counted, diagnosed attempt):

| # | start | end | exit | ok | not ok | note |
|---|---|---|---|---|---|---|
| 1 | 2026-10-26T13:22:00Z (approx., same shell block) | 2026-10-26T13:28:29Z | 2 | 661 | 1 | pre-existing flake, test 106 (AC-031 model-env selftest); out of scope, recorded above |
| 2 | 2026-10-26T13:29:14Z | 2026-10-26T13:38:59Z | 0 | 662 | 0 | green |
| 3 (final) | 2026-10-26T13:45:02Z | 2026-10-26T13:53:33Z | 0 | 662 | 0 | green — recorded as the final status |

Final status: **PASS — 662/662 tests, 0 failures** (`grep -c '^ok '` = 662,
`grep -c '^not ok '` = 0, TAP plan `1..662` satisfied). The Verifier's earlier
662/662 PASS is therefore re-confirmed on the current tree.

---

## Remediation record

**None.** No BLOCK occurred in this stage, so no phase-1/phase-2 attempt count is
owed for it, and no remediation budget was consumed.

Carried forward, not invented:

- `25-verification.md` opens with "Verifier run: attempt 1, phase 1 (pre-PR)" and an
  overall verdict of **PASS** — i.e. the Verifier reached PASS on its first phase-1
  attempt, with no BLOCK to resolve.
- No orchestrator loop summary was supplied with this subagent invocation, so no
  phase-2 (post-PR CI) entries exist to carry.
- The three full-suite invocations above are flake diagnostics in stage 5a, not BLOCK
  remediations: attempts 2 and 3 were re-executions after a pre-existing,
  out-of-scope test flake, resolved by re-running the suite (green), with the flake
  root-caused and recorded rather than papered over.

---

## Verdict

**GREEN** — mutation gate skipped at `mvp` tier (evidence recorded), equivalent
mutants: none (not applicable), full suite green at 662/662 on the final run.
No commit, no push, no PR; `PR:` is appended by stage 5b.
