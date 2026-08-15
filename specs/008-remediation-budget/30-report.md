# Architect Report — spec 008: Bounded remediation budget

Stage: 5a (Mutation Runner). Date: 2026-08-15. Branch: `spec/008-remediation-budget`.

## Verifier's verdict (carried forward)

**PASS** — from `25-verification.md` (attempt 1, phase 1, first full run). Independent
re-check of stages 2–3: AC-008 traceability clean (5/5 traced, no dangles); the new
check script runs green (84/84); orchestration, validate-all, lint, and self-ci YAML
all exit 0 with the "Check remediation budget" step present; complexity gate not
applicable (no Java/Go/TS/JS touched); design-principles gate exit 1 with all
FAILs/WARNs confined to untouched `ci/templates/*`; scenario-to-behavior spot checks
match; diff fully accounted for; mvp tier substantiated (no `AGENTS_*.md`).

## Mutation score

**skipped — `mvp` tier.** Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation
testing is a `production`-tier gate; at `mvp` it is skipped. The changed code is
shell scripts plus markdown prompts/docs — no mutation tooling for shell exists in
this repo, and no Java/Go/TS/JS files were touched. No mutation run was attempted.

## Complexity summary (carried from the Refactorer, via verification check 3)

No cyclomatic-complexity linter is configured for shell in this repo (repo tooling
covers Java/Go/JS/TS only). Manual count of the four named functions in
`scripts/check-remediation-budget.sh`, all within the ≤6 guideline and consistent
with the Refactorer's claim:

| Function | CC |
|---|---|
| `collapse_whitespace` | 1 (single pipeline) |
| `require_file` | 2 (single `if`) |
| `assert_contains` | 2 (single `if`) |
| `assert_absent` | 2 (single `if`) |

## Equivalent mutants

**None.** Mutation testing was not run (mvp tier), so no surviving mutants — and no
equivalent mutants — were produced. Nothing to name.

## Final test status (re-run after the mutation-skip note)

Full relevant suite re-executed this run, all green:

| Check | Exit | Result |
|---|---|---|
| `bash -n scripts/check-remediation-budget.sh` | 0 | syntax valid |
| `scripts/check-remediation-budget.sh` | 0 | every check passed (84/84 PASS, `✔ Remediation budget check: every check passed.`) |
| `scripts/check-orchestration.sh` | 0 | "All orchestration references valid." |
| `make validate-all` | 0 | all 35 required files present, cross-refs valid (1 pre-existing WARN: `skills/hallmark/SKILL.md` >500 lines, unrelated) |

`specs/008-remediation-budget/25-verification.md` exists with verdict **PASS**
(confirmed by direct read before any other action).

## Remediation record (per `docs/SPEC_PIPELINE.md §Remediation budget`)

**none** — no BLOCK occurred during this run. `25-verification.md` records
"Attempt 1, phase 1 (first full run)" with no re-verification attempt entries, so
there is no phase/attempt count to carry forward. Nothing was re-delegated or
re-verified.
