# Report — spec 035 autopilot mode

- **Stage:** 5a (Mutation Runner / Architect)
- **Branch:** `spec/035-autopilot-mode`
- **Base ref:** `main`
- **Verifier verdict carried forward:** **PASS** — `25-verification.md`, attempt 1, phase 1
  (`Overall verdict: PASS`, line 7; "The Architect may proceed", lines 479).
- **Work done at this stage:** mutation-tier ruling, mutation-skip evidence, final
  full-suite re-run, `45-decisions.md` written from the deterministic writer.
  No production code changed at this stage, nothing committed, nothing pushed.

Autopilot: true
Autopilot decisions: 0

## Verifier verdict (carried forward, not re-derived)

The Verifier's independent re-check is the precondition for this stage, so its verdict is
carried verbatim rather than re-asserted: `25-verification.md` line 7 reads
`- **Overall verdict: PASS**`, and every one of the five contract checks carries an
evidence block with `command:` / `exit:` / `at:` markers. This stage did not treat that
verdict as its own — it re-ran the full suite itself (below) because the mutation stage
adds new artifacts after the Verifier's run.

## Conformance tier ruling — `mvp`

Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a `production`-tier
gate. This repo declares no `production` tier, so the ruling is `mvp` and mutation
testing is a recorded skip, not a gap (`docs/CONFORMANCE_TIERS.md`, "Tiers are
cumulative", and the `production` row for "Mutation testing (PiTest / Gremlins /
Stryker)").

Evidence for the ruling:

```
$ grep -rn "Conformance tier: production" AGENTS.md AGENTS_*.md
(no output)
exit: 2

$ make mutation
skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)
exit: 0
```

The design-principles gate reports the same tier independently (`"tier": "mvp"` in both
JSON runs recorded in `25-verification.md`, lines 145 and 168).

Secondary confirmation that no mutation engine could run even at a higher tier: this
change set is bash-only. Changed-path extensions are `14 .bats`, `8 .md`, `7 .sh`,
`1 .jsonl` (`runs.jsonl` telemetry), plus the untracked `specs/` folder. There is no
`pom.xml`, `package.json`, or `stryker.conf.*` in the tree, so the repo has no PiTest,
gremlins/go-mutesting, or Stryker target to point at the change. Per the stage
instruction, this tooling gap is reported, not used to block.

## Evidence: mutation score

command: make mutation
exit: 0
at: 2026-10-26T08:31:35Z

```
skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)
```

**Mutation score: skipped — `mvp` tier** (tier evidence above; no Java/Go/JS mutation
engine present for a bash-only change set).

### Equivalent mutants

**None.** No mutation engine ran, so no mutant was generated, survived, or was judged
equivalent. There is therefore no un-killable-mutant list to name — an empty list here
means "mutation testing did not apply", not "every mutant was killed".

## Complexity summary (carried from the Refactorer via the Verifier)

The Refactorer writes no report artifact by design (`docs/SPEC_PIPELINE.md §Audit
contract`); the Verifier re-ran the structure gates and recorded the measurements. Carried
into this report unchanged:

| Measurement | Command | Exit | Result |
|---|---|---|---|
| Complexity (change-scoped) | `scripts/check-code-principles.sh --gates complexity -BaseRef main --json` | 0 | `"tier": "mvp"`, `"gates": ["complexity"]`, `"fails": []`, `"warns": []` |
| Design principles (change-scoped: complexity, dry, yagni, solid, component-per-file, property-tests) | `scripts/check-code-principles.sh -BaseRef main --json` | 0 | `"fails": []`, `"warns": []` |
| Property tests | tier-gated | — | skipped at `mvp` (`docs/CONFORMANCE_TIERS.md`: property testing is `production`) |

Zero complexity FAILs and zero complexity WARNs against the change: the four new
`scripts/autopilot-*.sh` files and the three extended gate scripts are all within the
≤6 cyclomatic bound. Copying `25-verification.md`'s caveat rather than smoothing it: the
**unscoped** design-principles run exits 1 on pre-existing debt
(`skills/hallmark/site/examples/cobalt-01/script.js`, CC=10) that reproduces identically
on a clean `main` worktree and is untouched by this branch — a WARN-level follow-up, not a
finding against this spec.

## Gate results

| Gate | Result | Evidence (from `25-verification.md`, re-run by the Verifier) |
|---|---|---|
| Scenario traceability | PASS | `scripts/check-scenario-traceability.sh --json` exit 0 at 2026-10-26T08:27:43Z; checks `[1, 2]`, 38 IDs traced (AC-035-01 … AC-035-38), `"fails": []` |
| Full test suite | PASS | `make test-scripts` exit 0 at 2026-10-26T08:18:33Z (529 ok / 0 not ok) and again at 2026-10-26T08:22:04Z (529 ok / 0 not ok) |
| Complexity gate | PASS | `scripts/check-code-principles.sh --gates complexity -BaseRef main --json` exit 0 at 2026-10-26T08:27:45Z |
| Design-principles gate | PASS (change-scoped) | `scripts/check-code-principles.sh -BaseRef main --json` exit 0 at 2026-10-26T08:27:46Z; unscoped pre-existing FAIL on `main` recorded, not introduced here |
| Scenario-to-behavior spot check | PASS | manual cross-check of AC-035-04, AC-035-21, AC-035-33 at 2026-10-26T08:26:00Z (assertions match Given/When/Then, not just IDs) |
| Mutation testing | SKIPPED (tier) | `make mutation` exit 0 at 2026-10-26T08:31:35Z — see §Evidence: mutation score |
| Final full suite (this stage) | PASS | `make test-scripts` exit 0 at 2026-10-26T08:35:46Z — see §Evidence: final test status |

Additional gates the Verifier ran beyond the five contract checks, also green:
`make validate-all` exit 0 and `scripts/check-orchestration.sh` exit 0 (all agent, skill,
script, and doc references resolve).

## Evidence: final test status

command: make test-scripts
exit: 0
at: 2026-10-26T08:35:46Z

Full-suite re-run performed at this stage, after the mutation ruling and after
`45-decisions.md` was written — the Verifier's green predates both. Raw output excerpt
(head, TAP plan) and tail:

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 65 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..529
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
...
ok 522 wire: score-shaped response exits 0 with answer the numeric score
ok 523 wire: usage carried only at the response top level populates per-question usage (input/output shape)
ok 524 wire: top-level usage of the total_tokens shape populates per-question usage too
ok 525 wire: per-answer usage wins over the top-level usage; no top-level usage keeps hosted behavior
ok 526 wire: mixed choice+noul request — low choice confidence exits 10 with BOTH answers printed
ok 527 wire: answer object with none of answer/choice/noul/score is incomplete, exits 10
ok 528 wire: non-numeric confidence is invalid, exits 10
ok 529 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
```

Counts: `529` `ok`, `0` `not ok`, plan `1..529`; `0` skipped (`# skip`); make exit 0.
All 38 spec-035 acceptance tests appear in the run (`grep -c '^ok .*AC-035'` → 38),
matching the 38 scenario IDs the traceability check requires: every scenario is still
traced to a passing test at final status.

Two artifacts this stage added could in principle affect the suite: `45-decisions.md`
existed before the run, `30-report.md` did not. Cheap confirmation that neither disturbs
the green, and that the autopilot rule still bites, after both existed:

command: bats --tap scripts/tests/check-audit-trail.bats scripts/tests/autopilot-enforcement.bats scripts/tests/autopilot-decisions.bats
exit: 0
at: 2026-10-26T08:37:21Z

```
ok 1 check-audit-trail: no slug exits 2 and prints the usage block
ok 2 check-audit-trail: an absent spec folder is 'nothing to check' and exits 0
ok 3 check-audit-trail: a spec folder missing 25-verification.md exits 1
ok 4 check-audit-trail: --selftest exercises every negative case and exits 0
ok 5 AC-035-33 — 'Autopilot: true' without 45-decisions.md FAILs the folder
ok 6 AC-035-34 — 'Autopilot: true' with a non-empty 45-decisions.md exits 0
ok 7 AC-035-35 — without the marker, 45-decisions.md is optional either way
ok 8 AC-035-36 — no pipeline agent contains an unconditional ask path (repo exits 0)
ok 9 AC-035-18 — each decision entry records the six labelled fields, At being ISO-8601 UTC
ok 10 AC-035-19 — a run that resolves nothing writes exactly the no-decision line
ok 11 AC-035-20 — 30-report.md carries Autopilot: true and the entry count
ok 12 unit — add rejects a missing field and a malformed timestamp, leaving the file untouched
```

## Autopilot record

This run executed under autopilot. No ask reached a genuine fork that autopilot had to
resolve, so `scripts/autopilot-decisions.sh none specs/035-autopilot-mode/45-decisions.md`
wrote the single documented line (`exit 0`; `count` → `0`):

```
No autopilot decisions were required
```

`Autopilot decisions: 0` above therefore matches the entry count in
`45-decisions.md` (`scripts/autopilot-decisions.sh count` → `0`), which is the
consistency rule from Task 6 / AC-035-20. The marker is non-empty, satisfying the
`check-audit-trail.sh` autopilot rule (AC-035-33/34).

Two conditions evaluated at this stage are recorded here as **dispositions, not
decisions**, because each had exactly one permitted outcome and no alternative was weighed:

- **Working tree dirty** — the tree carries this spec's own uncommitted change set (every
  path accounted for in `25-verification.md §No unaccounted behavior`; commits are stage
  5b's job). The clean-tree rule is a start-of-item preflight
  (`scripts/autopilot-preflight.sh` step 4, run by `/autopilot` "before each queue
  item"), not a per-stage gate — mid-pipeline implementation dirt is the expected state
  between stage 2 and stage 5b.
- **Project type / tier** — resolved to `mvp` by the tier declaration rule, not by a
  judgement call (see §Conformance tier ruling). No ambiguity arose.

## Remediation record

**none.** No BLOCK occurred in this run. `25-verification.md` records a single attempt
("**Attempt:** 1, phase 1 (full verification, first run)") with verdict PASS and no
re-verification entries, so there is no phase-1 or phase-2 attempt count to carry forward.
The orchestrator's loop summary reports no block either. Nothing in this section is
guessed or invented: where the source is silent, this report says so rather than
supplying a phase and attempt number.

## Evidence: audit-trail gate

command: scripts/check-audit-trail.sh 035-autopilot-mode
exit: 0
at: 2026-10-26T08:36:42Z

Verbatim (ANSI colour codes from the script's own output stripped, no wording changed):

```
PASS 035-autopilot-mode: 10-tasks.md present and non-empty
PASS 035-autopilot-mode: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 035-autopilot-mode: 25-verification.md present and non-empty
PASS 035-autopilot-mode: 30-report.md present and non-empty
PASS 035-autopilot-mode: 45-decisions.md present and non-empty for an autopilot run (AC-035-34)
PASS 035-autopilot-mode: evidence block 'scenario traceability' — command: scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-10-26T08:27:43Z
PASS 035-autopilot-mode: evidence block 'full test suite' — command: make test-scripts, exit: 0, at: 2026-10-26T08:18:33Z
PASS 035-autopilot-mode: evidence block 'complexity gate' — command: scripts/check-code-principles.sh --gates complexity -BaseRef main --json, exit: 0, at: 2026-10-26T08:27:45Z
PASS 035-autopilot-mode: evidence block 'design-principles gate' — command: scripts/check-code-principles.sh -BaseRef main --json, exit: 0, at: 2026-10-26T08:27:46Z
PASS 035-autopilot-mode: evidence block 'scenario-to-behavior spot check' — command: manual cross-check of acceptance scenarios AC-035-04, AC-035-21, AC-035-33 against the assertions in scripts/tests/*.bats, exit: 0, at: 2026-10-26T08:26:00Z
✔ Audit-trail check: specs/035-autopilot-mode complete, verifier evidence recorded.
```

The `45-decisions.md` line is the autopilot rule in action: `Autopilot: true` in this
report is accepted only because `45-decisions.md` exists and is non-empty (AC-035-34).

## Warnings and notes carried forward (non-blocking)

- **WARN — pre-existing full-tree design-principles FAIL:**
  `skills/hallmark/site/examples/cobalt-01/script.js` (CC=10). Reproduces identically on a
  clean `main` worktree; untouched by this branch. Follow-up candidate (a separate spec),
  never fixed inside this run.
- **WARN — pre-existing doc-size hint:** `make validate-all` reports
  `skills/hallmark/SKILL.md` body 562 lines (>500 recommended). Unrelated, unchanged.
- **NOTE — executable bit:** `scripts/record-gate-run.sh` is not executable in this
  checkout, so `./scripts/record-gate-run.sh` exits 126; the documented
  `bash scripts/record-gate-run.sh` form works (exit 0). Same pre-existing shape recorded
  by earlier specs, not introduced here.
- **NOTE for stage 5d (Archiver):** `30-report.md` now exists, so this folder is
  *finished* — `scripts/check-specs-archived.sh` (self-ci `validate`, no
  `continue-on-error`) will fail the merge until `scripts/archive-spec.sh 035-autopilot-mode`
  runs as the pipeline's final act. Expected flow, flagged so it is not mistaken for a
  regression at PR time.

## Verdict

**GREEN.** Verifier PASS carried forward; mutation testing recorded as a tier skip with
executable evidence (`make mutation` exit 0, `mvp` tier); no equivalent mutants (no engine
ran); final full suite re-run green at 529 ok / 0 not ok / 0 skipped after this stage's
artifacts landed. Complexity summary carried from the Verifier's re-run of the Refactorer's
gates with zero findings. Stage 5b (PR Opener) may proceed.

PR: https://github.com/RexiAI/my-engineering-standards/pull/102
Commits on branch (vs main): 15 (13 task commits + spec artifacts + this PR-record commit)
