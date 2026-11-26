# Architecture Decision Record (ADR)

## Title

Scope scenario traceability to the spec under verification

## Status

Proposed

## Context

`docs/spec-pipeline/specifier.md` lets the Specifier number scenarios per task
inside one spec folder (`AC-<task>-<n>`, e.g. `AC-008-02`). The traceability
gate, `scripts/check-scenario-traceability.sh`, scans every
`specs/*/20-acceptance/*.md` and demands a test for every heading (check 1).
When several spec folders are in flight at once (observed in a child repo with
`specs/003` and `specs/004`..`010` open), task-numbered IDs collide across
folders and one spec's untested scenarios fail an unrelated spec's Verifier.
The gate result for spec A then depends on the state of spec B, which the
Verifier cannot and must not fix.

This changes the gate catalog, so an ADR is required (`docs/GOVERNANCE.md
§ADR Requirement`).

## Decision

Add a `--spec <NNN-slug|NNN>` option to `scripts/check-scenario-traceability.sh`.
With it, check 1 traces only `specs/<NNN-slug>/20-acceptance/*.md`. A missing or
ambiguous folder exits 2 (BLOCK), never a clean pass. Check 2 is unchanged: a
test reference still resolves against every in-flight and archived source.
Without `--spec` the script behaves exactly as before. The Verifier always
passes `--spec` for the spec under verification (`docs/spec-pipeline/verifier.md`,
`agents/spec-verifier.md`).

The gate is not weakened for the spec under verification: every one of its
scenarios must still be traced to a test.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| `--spec` scoping of check 1 (chosen) | Small, backwards compatible, isolates specs, no ID migration | A colliding test reference in check 2 can resolve against another spec's heading (same as today) |
| Spec-namespaced IDs (`S003-AC-008-02`) | Globally unique IDs; check 2 exact too | Every grep pattern, test naming rule, archive script and existing test changes; large migration for child repos |
| Require `AC-<spec>-<n>` strictly | Already the documented intent | Breaks repos that number per task; does not fix existing in-flight folders |

Namespaced IDs remain a possible follow-up; `--spec` does not preclude them.

## Consequences

- A spec's Verifier verdict depends only on that spec's scenarios plus resolvable test references.
- Unscoped runs (self-ci, manual audits) still report every in-flight spec, so other specs' gaps stay visible.
- Check 2 keeps its current cross-folder tolerance for colliding IDs.

## Compliance

`scripts/check-scenario-traceability.selftest.sh` covers the collision case
(scoped pass, scoped fail, prefix resolution, ambiguous and missing folder exit
2, unscoped fail) and runs in self-ci. Reviewers check that the Verifier docs
keep passing `--spec`.

## Notes

- 2026-11-26: Decision recorded
