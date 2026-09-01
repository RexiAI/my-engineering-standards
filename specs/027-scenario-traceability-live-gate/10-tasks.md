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
