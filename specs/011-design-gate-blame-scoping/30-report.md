# Mutation & Gate Report — spec 011: Design-gate blame scoping

Stage 5a (Mutation Runner). Branch: `spec/011-design-gate-blame-scoping`. Date: 2026-08-15.

## Verifier's verdict (carried forward)

**PASS** — `specs/011-design-gate-blame-scoping/25-verification.md` exists, verdict
`PASS — the Architect may proceed`. All AC-011 scenarios traced (scoped run exit 0),
full relevant suite green, complexity gate clean for new code, design-principles gate
shows zero FAILs attributable to 011, 9 independent scenario spot-checks passed.

## Mutation score

**skipped — `mvp` tier.**

Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a `production`-tier
gate; this repo is `mvp` tier (no `AGENTS_<PROJECT>.md` at repo root; archived specs
020/021/022 confirm). Changed code is bash scripts + markdown; no mutation tooling for
shell exists in this repo. No mutation run attempted, no mutants generated.

## Complexity summary (carried from the Refactorer, per Verifier re-measurement)

- 15 new bash helper functions, all ≤6 decision points (max: `compute_diff` 5,
  `ranges_overlap` 4): `blocking_raw`, `valid_gate`, `resolve_blocking_set`, `abs_of`,
  `is_blocking`, `file_touched`, `file_fully_added`, `ranges_overlap`, `classify_blame`,
  `classify`, `emit`, `collect_rel_paths`, `hunk_range`, `parse_diff_hunks`, `compute_diff`.
- Real reduction: `check_solid_dip` 7→4; single routing path (`classify`/`emit`) replaces
  inline fail/warn at 19 sites (now 16 through `emit` + 3 deliberate direct `fail` in
  property-tests — the AC-011-03-05 presence gate, never blame-scoped).
- **Pre-existing, unchanged from `main`, out of scope for 011:** `check_yagni` ~18,
  `check_solid_ocp` 8, `check_solid_isp` 7. The Refactorer's "worst offender after ≤6"
  claim is not substantiated for these functions; the ≤6 rule is not enforced on bash by
  any tool in this repo. Carried forward as the Verifier's review hint (a) for the
  Architect — not a spec defect.

## Equivalent mutants

**None.** Mutation testing not run (`mvp` tier), so no mutants were generated and none
survived.

## Final test status

Re-confirmed after Verifier's PASS (new carrier test code covered by this run):

| Check | Exit | Result |
|---|---|---|
| `bash -n scripts/check-code-principles.sh` | 0 | syntax OK |
| `bash -n scripts/tests/check-code-principles-blame.sh` | 0 | syntax OK |
| `bash scripts/tests/check-code-principles-blame.sh` | 0 | **24 passed, 0 failed** (all AC-011-01/02/03 families) |
| `bash scripts/check-orchestration.sh` | 0 | all references valid |
| `make validate-all` | 0 | all validations passed (1 pre-existing WARN: `skills/hallmark/SKILL.md` 562 lines — unrelated to 011) |

Full suite green. `25-verification.md` present with PASS.

## Gates for the Architect (carried review hints, non-blocking)

- (a) Refactorer's complexity self-report overstates the reduction (`check_yagni`/`ocp`/`isp` unchanged from main).
- (b) CI's shellcheck step globs `scripts/*.sh`, not `scripts/tests/` — the new carrier is shellcheck-silent in CI (bash -n still covers it).
- (c) `--blocking ""` on a no-arg call is exit 2 by design — callers must pass a non-empty list.

No commit, push, or PR performed — that is the PR Opener's job (stage 5b).
