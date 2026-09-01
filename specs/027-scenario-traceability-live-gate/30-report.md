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
