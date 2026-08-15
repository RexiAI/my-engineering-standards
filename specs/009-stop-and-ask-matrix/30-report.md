# Mutation Runner Report — Spec 009: Stop-and-Ask decision matrix

- **Stage**: 5a (Mutation Runner)
- **Date**: 2026-08-15
- **Branch**: `spec/009-stop-and-ask-matrix`
- **Tier**: `mvp` (no `AGENTS_<PROJECT>.md` at repo root — confirmed by Verifier Check 3.5)

---

## Verifier verdict (carried forward)

**PASS** — `specs/009-stop-and-ask-matrix/25-verification.md` exists, verdict PASS. All five Verifier checks pass: AC-009 scenario traceability clean, full relevant suite green, complexity gate ≤6, no design-principles FAIL/WARN attributable to this spec, scenario-to-behavior spot checks (incl. live negative fixtures) pass, no unaccounted behavior.

## Mutation score

**skipped — mvp tier.** Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a `production`-tier gate and is skipped at `mvp`. Additionally, the changed code is a shell check script (`scripts/check-stop-and-ask-matrix.sh`) plus markdown docs/agent prompts — no mutation tooling for shell exists in this repo, and none applies to markdown. No mutation tooling attempted.

## Complexity summary (carried from the Refactorer, re-confirmed by the Verifier)

No PMD/golangci/eslint applies (bash + markdown footprint). Shell-complexity gate is the ≤6 decision-point rule from `docs/CODING_CONVENTIONS.md`, enforced by inspection:

- `edit_effective_action` — **5** (`&&`×3, `while`×1, `if`×1) — worst offender, ≤6 ✓
- `glob_to_regex` — 0 (single `printf | sed` pipeline) ✓
- `extract_matrix_section` — 0 (one awk command substitution) ✓
- `fail`/`pass` — 0 ✓

No function over 6; worst offender `edit_effective_action` = 5. Refactorer end-state confirmed: `glob_to_regex` pipelines consolidated 3→1; zero empty-then branches remain.

## Equivalent mutants

**None.** No mutation run was performed (mvp tier), so no mutants of any kind — equivalent or otherwise — were generated.

## Final test status

Full relevant suite re-run one final time after the skip note (no new code was written this stage, so no mutation-kill tests exist to cover):

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-stop-and-ask-matrix.sh` | 0 | syntax clean |
| `scripts/check-stop-and-ask-matrix.sh` | 0 | every check PASS; all 20 AC-009-NN-NN sub-IDs cited in output |
| `scripts/check-orchestration.sh` | 0 | "All orchestration references valid." |
| `make validate-all` | 0 | "All validations passed." (1 pre-existing WARN: `skills/hallmark/SKILL.md` body 562 lines >500 — untouched by this spec) |
| `specs/009-stop-and-ask-matrix/25-verification.md` | — | exists, verdict **PASS** |

**GREEN.** Spec 009 complete and gate-clean at `mvp` tier. Stage 5b (PR Opener) may proceed.
