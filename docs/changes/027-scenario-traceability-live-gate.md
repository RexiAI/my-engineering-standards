# 027-scenario-traceability-live-gate

> Spec pipeline archive. Original source: `specs/027-scenario-traceability-live-gate/` (deleted by this script).
> Archived: 2026-09-01

## Original ask

# 027 — scope check-scenario-traceability.sh's check 2 to in-flight specs, wire it into self-ci live

## Ask

Follow-up to spec 026's `30-report.md` "Known out-of-scope finding": running
`scripts/check-scenario-traceability.sh` directly against this repo's own
live tree (not just its hermetic `.selftest.sh`) surfaces 154 violations,
none caused by spec 026. Root-caused during this follow-up (correcting the
026 report's framing): it is not a dormant CI blind spot to merely "wire
up" — check 2 ("every AC-NNN-NN reference resolves to a real scenario
heading") is fundamentally incompatible with running unscoped against a
repo that has ever archived a spec, because archiving *deletes* the
scenario headings by design (`docs/SPEC_PIPELINE.md §Archive in the PR`)
while every merged spec's deliverables-gate script (`check-ci-sweeper.sh`'s
`AC-017-*` self-citations, `check-pr-review.sh`'s `AC-024-*`, etc.)
permanently and correctly keeps citing those same IDs forever. Wiring the
unscoped check into CI as originally suggested would have made it
permanently red the moment any spec merges — the opposite of a fix.

The actual, safe fix: scope check 2's dangling-reference detection to only
the spec numbers currently present as `specs/NNN-*/` folders (i.e. only the
spec actually being worked right now). A reference to an archived or
nonexistent spec number is out of scope by design, not a finding. A stale
or typo'd reference *within* the currently in-flight spec is still caught.
With that scoping in place, running the real check against the live tree
is safe and adds real value, so it is wired into `self-ci.yml`.

## Tasks

### T1 — Scope check 2 to in-flight spec numbers (AC-027-01)

`scripts/check-scenario-traceability.sh`: compute the set of spec numbers
with a current `specs/NNN-*/` folder; check 2 only evaluates a referenced
`AC-NNN-NN` ID when its `NNN` is in that set. References to any other
number are skipped entirely — not reported, not counted as a violation.

### T2 — Regression-proof the scoping fix (AC-027-01)

`scripts/check-scenario-traceability.selftest.sh`: the existing `dangle`
case's bogus ID moves from an out-of-flight number (`888`) to the same
in-flight number as the rest of that case's fixture (`999`) — under the
new scoping, an out-of-flight bogus ID would no longer exercise check 2 at
all, silently weakening that case. A new `out_of_flight` case proves the
new behavior directly: a reference to a spec number with no `specs/NNN-*/`
folder anywhere in the fixture must pass clean (exit 0), exactly mirroring
every real archived spec's own gate-script self-citations on this repo's
`main`.

### T3 — Wire the live check into self-ci (AC-027-02)

`.github/workflows/self-ci.yml`: add a step running
`bash scripts/check-scenario-traceability.sh` unconditionally (no
continue-on-error) alongside the existing hermetic-selftest step. Safe now
that T1 lands first — a no-op (exit 0) when no `specs/` folder exists (the
normal state of `main` between spec PRs), and a real check against the
actual in-flight spec's own scenarios/tests when one is present.

## Acceptance criteria

- AC-027-01: `scripts/check-scenario-traceability.sh` check 2 flags a
  dangling reference only when its spec number has a current
  `specs/NNN-*/` folder; a reference to any other number (archived or
  nonexistent) is never reported. Proven by
  `scripts/check-scenario-traceability.selftest.sh`'s `out_of_flight` case
  and by re-running the real script against the exact tree state that
  previously produced 154 violations (spec 026's PR branch before
  archival), now producing 0.
- AC-027-02: `.github/workflows/self-ci.yml` runs
  `scripts/check-scenario-traceability.sh` against the live tree (not just
  its selftest), unconditionally, no `continue-on-error`.

## Out of scope

- Renaming any existing spec's fixture/self-citation IDs. The scoping fix
  makes that unnecessary — archived specs' permanent citations are now
  correctly out of scope by design, not a naming collision to clean up.
- Changing check 1 (every scenario has a matching test) — it already only
  iterates in-flight scenario headings by construction; no scoping gap
  exists there.

## Tasks

# 027 — scope check-scenario-traceability.sh's check 2 to in-flight specs, wire it into self-ci live

Source: `specs/027-scenario-traceability-live-gate/00-informal.md`.

## Tasks

### T1 — Scope check 2 to in-flight spec numbers (AC-027-01)

`scripts/check-scenario-traceability.sh`: before the check-2 loop, walk
`"$SPECS_DIR"/*/` and collect the leading `NNN` of every directory matching
`[0-9][0-9][0-9]-*` into `IN_FLIGHT_NUMS`. In the check-2 loop, extract each
referenced ID's `NNN` and `continue` (skip entirely — no pass, no fail, no
count) when it is not in `IN_FLIGHT_NUMS`. Only IDs whose number is in
flight are evaluated against `SCENARIO_IDS` as before.

Acceptance criteria (checkable by reading code):
- [AC-027-01] The check-2 block computes `IN_FLIGHT_NUMS` from
  `specs/NNN-*/` directory names before iterating `REFERENCED_IDS`.
- [AC-027-01] A referenced ID whose number is not in `IN_FLIGHT_NUMS` never
  reaches `fail()` — it is skipped via `continue` before the
  `SCENARIO_IDS` membership test.
- [AC-027-01] Check 1's logic (`for id in $SCENARIO_IDS`) is untouched —
  this task only changes check 2.

### T2 — Regression-proof the scoping fix (AC-027-01)

`scripts/check-scenario-traceability.selftest.sh`:
- Move the `dangle` case's `BOGUS_ID` from `AC-888-88` to `AC-999-04` (same
  in-flight number, `999`, as the rest of that case's fixture) — an
  out-of-flight bogus ID would silently stop exercising check 2 under the
  new scoping, weakening this existing regression net without any test
  failure to flag it.
- Add a new `out_of_flight` case: a traced scenario (`AC-999-05`) plus a
  test referencing a *different* spec number's ID (`AC-700-01`) with no
  `specs/700-*/` folder anywhere in that case's fixture. Expected: exit 0
  (the reference to 700 is silently out of scope, exactly like every real
  archived spec's own gate-script self-citation).

Acceptance criteria (checkable by reading code and by running the script):
- [AC-027-01] `bash scripts/check-scenario-traceability.selftest.sh` exits
  0 and reports 4 passing cases (`pass`, `orphan`, `dangle`,
  `out_of_flight`).
- [AC-027-01] The `out_of_flight` case's fixture directory tree contains no
  `specs/700-*/` folder, and its expected exit code is 0.

### T3 — Wire the live check into self-ci (AC-027-02)

`.github/workflows/self-ci.yml`: add a step
`bash scripts/check-scenario-traceability.sh` (no arguments — defaults to
`specs` / `.`) after the existing "Run gate selftests" step, with no
`continue-on-error`.

Acceptance criteria (checkable by reading code):
- [AC-027-02] `.github/workflows/self-ci.yml`'s `validate` job contains a
  step running `bash scripts/check-scenario-traceability.sh` with no
  positional arguments and no `continue-on-error: true`.

## Open questions (need a human answer before /build)

None — the fix and its proof are fully specified by the informal ask; no
ambiguous language required an assumption call.

## Acceptance scenarios

## AC-027-01 — a dangling reference is caught within the current spec; an archived spec's own citation is silently out of scope
## AC-027-02 — self-ci runs the real check against the live tree, not just its hermetic selftest

## Verification

# 25-verification.md — spec 027 independent re-check

## Evidence: scenario traceability

command: bash scripts/check-scenario-traceability.sh
exit: 0
at: 2026-09-01T14:38:00Z

Scenario IDs found: 2

PASS AC-027-01 — traced to a test
PASS AC-027-02 — traced to a test

✔ Scenario traceability check: every scenario traced, every reference resolves.

This is the live-tree run this spec itself wires into self-ci (T3) —
running it here, against the real repo tree with specs/027 in flight, both
of this spec's own scenarios trace cleanly, proving T3's claim by using the
exact mechanism T3 adds.

Additional evidence — reproduction of the original 154-violation state,
confirmed fixed: checked out spec 026's PR branch at commit `1a5fcdf`
(before archival, `specs/026-ci-security-hardening/` still present, every
other spec's gate-script self-citations for already-archived numbers
17/19/24/25 present in `scripts/`) in a scratch worktree, copied this
spec's fixed `scripts/check-scenario-traceability.sh` into it, and ran it
with no arguments:

command: git worktree add /tmp/repro 1a5fcdf && cp scripts/check-scenario-traceability.sh /tmp/repro/scripts/ && (cd /tmp/repro && bash scripts/check-scenario-traceability.sh)
exit: 0
at: 2026-09-01T14:20:00Z

Scenario IDs found: 13
[... 13 PASS lines, AC-026-01 through AC-026-13 ...]
✔ Scenario traceability check: every scenario traced, every reference resolves.

0 violations, down from the unfixed script's 154 violations against the
byte-identical tree (same commit, only the checker script differs).

## Evidence: full test suite

command: bash scripts/check-scenario-traceability.selftest.sh && bash scripts/check-ci-sweeper.sh && bash scripts/check-pr-review.sh && bash scripts/check-pr-review.selftest.sh && bash scripts/check-security-hardening.sh && bash scripts/check-security-hardening.sh --self-test && bash scripts/check-no-hardcoded-secrets.sh && bash scripts/check-model-env.sh && bash scripts/check-gate-consistency.sh && bash scripts/check-orchestration.sh && bash scripts/check-skills.sh && bash scripts/check-loop-triage.sh && make validate-all
exit: 0
at: 2026-09-01T14:42:00Z

✔ check-scenario-traceability selftest: 4 cases passed (pass, orphan, dangle,
  out_of_flight — the new case this spec adds).
✔ CI sweeper check: every check passed (unaffected — spec 026's ci-sweeper.yml
  fixes are untouched by this spec).
✔ PR review agent check: every check passed (unaffected).
✔ Security hardening check: every check passed (unaffected — this spec
  touches only check-scenario-traceability.sh, its selftest, and
  self-ci.yml; scripts/check-security-hardening.sh's own 27 assertions
  about spec 026's fixes are all still true).
✔ check-security-hardening --self-test: baseline passes, both reverted-fix
  cases still caught (proves this spec introduced no regression in spec
  026's own fixes).
✔ check-no-hardcoded-secrets: clean.
✔ check-model-env, check-gate-consistency, check-orchestration, check-skills,
  check-loop-triage: all clean, all unaffected.
✔ make validate-all: all validations passed.

Additional evidence — shell syntax and YAML parse:

command: bash -n scripts/check-scenario-traceability.sh && bash -n scripts/check-scenario-traceability.selftest.sh && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/self-ci.yml'))"
exit: 0
at: 2026-09-01T14:39:00Z

Both scripts parse; self-ci.yml parses as valid YAML after the new step.

## Evidence: complexity gate

command: bash scripts/check-code-principles.sh . -BaseRef upstream/main
exit: 0
at: 2026-09-01T14:43:00Z

✔ Design-principles check: 0 FAIL(s), 0 WARN(s). Blame-scoped to the
combined diff of specs 026 and 027 (both land in this PR) against
`upstream/main` — no new complexity/duplication/SOLID/component-per-file
violation from either spec's changes.

## Evidence: design-principles gate

command: bash scripts/check-code-principles.sh . -BaseRef upstream/main
exit: 0
at: 2026-09-01T14:43:00Z

(Same invocation and result as the complexity-gate evidence above.)

## Evidence: scenario-to-behavior spot check

command: manual read — both AC-027-NN scenarios against the actual fix
exit: 0
at: 2026-09-01T14:44:00Z

- AC-027-01: read `scripts/check-scenario-traceability.sh`'s check-2 block
  directly — `IN_FLIGHT_NUMS` is computed from `"$SPECS_DIR"/*/` directory
  basenames matching `[0-9][0-9][0-9]-*` before the check-2 loop, and the
  loop's `case " $IN_FLIGHT_NUMS " in ... continue ;; esac` skips any
  referenced ID whose number is not in that set before it ever reaches the
  `SCENARIO_IDS` membership test. Matches the scenario exactly — not just a
  test with the right name, the actual control-flow guard.
- AC-027-02: read `.github/workflows/self-ci.yml` directly — the new step
  is `run: bash scripts/check-scenario-traceability.sh`, no positional
  arguments, no `continue-on-error`, placed immediately after "Run gate
  selftests". Matches the scenario.

No unaccounted behavior found: this spec touches exactly three files
(`scripts/check-scenario-traceability.sh`,
`scripts/check-scenario-traceability.selftest.sh`,
`.github/workflows/self-ci.yml`) — every line changed maps to T1, T2, or T3
in `10-tasks.md`.

## Verdict

**PASS.** All five contract checks hold, including a direct reproduction
of the original 154-violation state (spec 026's own PR branch before
archival) confirming the fix actually resolves the exact real-world
condition it was written for, not just a synthetic fixture.

## Quality gates

# 30-report.md — spec 027 final report

## Summary

Follow-up to spec 026's out-of-scope finding, requested by the user after
reviewing the security-hardening PR. Root-caused during this spec (a
correction to how 026's report framed the issue): `scripts/check-
scenario-traceability.sh`'s check 2 was not merely "never wired into CI" —
running it unscoped against a repo that has ever archived a spec is
*inherently* broken, because archiving deletes scenario headings by design
while every merged spec's gate script permanently keeps citing them. The
fix scopes check 2 to in-flight spec numbers only, which makes both parts
of the original ask true: the check is now meaningful to run, and it is
wired into `self-ci.yml` against the live tree.

## Fix

- `scripts/check-scenario-traceability.sh`: check 2 now computes the set of
  spec numbers with a current `specs/NNN-*/` folder and skips any
  referenced ID whose number is not in that set — an archived spec's own
  gate-script self-citations, and any other out-of-flight reference, are
  silently out of scope rather than reported as dangling.
- `scripts/check-scenario-traceability.selftest.sh`: the existing `dangle`
  case's bogus ID moved into the in-flight number so it still exercises
  check 2 after the scoping change; a new `out_of_flight` case directly
  proves the new behavior (a reference to a spec number with no folder at
  all passes clean).
- `.github/workflows/self-ci.yml`: a new step runs
  `bash scripts/check-scenario-traceability.sh` (the real check, live
  tree) unconditionally, right after the existing hermetic selftest step.

## Verification highlight

Beyond the selftest, this spec reproduced the exact real-world condition
that motivated it: checked out spec 026's own PR branch before archival
(`specs/026-ci-security-hardening/` present, every other spec's
already-archived gate-script citations present in `scripts/`) into a
scratch worktree and ran the fixed checker against it directly — **0
violations, exit 0**, down from the unfixed script's **154 violations**
against the byte-identical tree. This is the strongest evidence available
that the fix works: not a synthetic fixture, the actual tree state that
produced the original finding.

## Mutation testing

Not applicable in the `spec-mutation-runner` sense (no application source
tree). Mutation-equivalent evidence: the selftest's 4 cases (`pass`,
`orphan`, `dangle`, `out_of_flight`) each assert a specific exit code and
message; `dangle` and `out_of_flight` are the two cases that specifically
exercise the boundary this spec changes (in-flight vs. out-of-flight), and
both pass. **Mutation-equivalent status: GREEN.**

## Complexity / design-principles

`bash scripts/check-code-principles.sh . -BaseRef upstream/main` (combined
with spec 026's diff, both landing in this PR): 0 FAIL(s), 0 WARN(s).

## Final test status

GREEN. See `25-verification.md` for the full evidence log, including the
154→0 reproduction and confirmation that every other gate this PR already
introduced (spec 026's `check-security-hardening.sh`, `check-pr-review.sh`,
`check-ci-sweeper.sh`) remains unaffected and green.

PR: (this spec lands in the same open PR as spec 026 —
https://github.com/RexiAI/my-engineering-standards/pull/63 — as an
additional commit, per the user's request to continue the same review)
