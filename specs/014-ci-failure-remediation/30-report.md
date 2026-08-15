# Mutation / Gate Report — spec 014 (CI-failure check-and-remediate loop)

**Stage:** 5a Mutation Runner
**Branch:** `spec/014-ci-failure-remediation`
**Date:** 2026-08-15

## Verifier's verdict (carried forward)

**PASS** — `specs/014-ci-failure-remediation/25-verification.md` (2026-08-15):
all spec-014-attributable gates green — traceability clean for AC-014 (37/37
sub-IDs asserted bidirectionally), suite green, complexity claims hold,
spot checks match Given/When/Then, no unaccounted behavior. The design-principles
gate's 5 FAIL / 17 WARN are confined to `ci/templates/*`, pre-existing repo debt
not attributable to 014.

## Mutation score

**Skipped — `mvp` tier.**

Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a
`production`-tier gate; `mvp` runs the 4-stage pipeline (Specifier, Coder,
Refactorer, Verifier). No mutation tooling attempted. (Also, the changed code
is a bash check script + markdown prompts/docs + workflow YAML; this repo has
no mutation tooling for shell.)

## Complexity summary (carried from the Refactorer, re-verified by the Verifier)

- All functions ≤2 (no applicable complexity linter for shell):
  - `pass`, `fail`, `section`, `contains`, `absent` = 1 (no branches)
  - `frontmatter`, `str_contains`, `str_absent` = 2 (single if/else)
  - Top-level agent-resolution `while` loop = 2 (one if/else)
- `contains`/`absent` are thin one-line delegates to `str_contains`/`str_absent`.
- SIGPIPE flake fix: `grep -q ... <<< "$hay"` (here-strings) instead of pipes,
  with `set -o pipefail`.

## Equivalent mutants

**None.** No mutants generated (mutation testing not run at `mvp` tier), so no
un-killable equivalents to name.

## Final test status

Re-run 2026-08-15, all green:

| Check | Exit | Result |
|---|---|---|
| `bash -n scripts/check-post-pr-ci-loop.sh` | 0 | syntax OK |
| `bash scripts/check-post-pr-ci-loop.sh` | 0 | **125 PASS / 0 FAIL** — "all assertions hold" |
| `scripts/check-orchestration.sh` | 0 | "All orchestration references valid" |
| `make validate-all` | 0 | "All validations passed" (1 pre-existing SKILL.md WARN, `skills/hallmark`) |
| `25-verification.md` present | — | verdict PASS |

### Assertion-count reconciliation

Live re-run (ANSI-stripped): **125 PASS, 0 FAIL** — per task
task1=23, task2=19, task3=20, task4=51, task5=12 (sum 125). This matches the
Refactorer's report and the Verifier's measured count exactly. The Coder's
"92/92 PASS" is unreproducible from the current tree (the script is untracked,
so no prior revision exists to diff against); recorded as a stale/inconsistent
count — non-blocking, and the authoritative gate number is 125. All 37
AC-014 sub-IDs are asserted; the Verifier's negative fixture proved the
assertions detect injected wrong content.

## Conclusion

GREEN for the `mvp` conformance tier. Stage 5b (PR Opener) may proceed: run
`scripts/archive-spec.sh 014-ci-failure-remediation`, push, open the draft PR.
