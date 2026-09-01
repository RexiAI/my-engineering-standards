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
