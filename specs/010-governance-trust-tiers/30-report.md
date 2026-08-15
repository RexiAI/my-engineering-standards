# Report — spec 010 (governance-trust-tiers)

Mutation Runner: stage 5a, `agents/spec-mutation-runner.md` discipline.

## Verifier's verdict (carried forward)

**PASS** — `specs/010-governance-trust-tiers/25-verification.md` exists and its
verdict is PASS. All eight verdict reasons verified by the Verifier's own
execution (traceability 37/37 AC-010 sub-IDs clean, negative fixtures, complexity,
design-principles gate, scenario spot-checks, mvp tier confirmed).

## Mutation score

**skipped — `mvp` tier**

Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a
`production`-tier gate; at `mvp` the Architect row is `skip`. The repo is `mvp`
(no `AGENTS_*.md`, confirmed by the Verifier's auto-detection: `(tier: mvp)`).
No mutation tooling attempted — the changed code is a shell check script plus
markdown docs; no mutation tooling exists for shell in this repo regardless of
tier.

## Complexity summary

Carried from the Refactorer via the Verifier's independent re-measurement
(`scripts/check-code-principles.sh` heuristic, counted via awk over the script).
**All functions ≤ 6 — cyclomatic-complexity rule holds, no gate violation.**

| Function | CC | Note |
|---|---|---|
| `extract_section` | 2 | — |
| `check_section` | 2 | matches Refactorer's claim |
| `expect` | 6 | at the ≤6 limit, "by design"; matches |
| `expect_row` | 5 | **does not reproduce Refactorer's claimed 2** (two `&&`/`||` guard expressions) |
| `check_failure_mode` | 1 | **does not reproduce Refactorer's claimed 2** |

Verifier-recorded discrepancies, carried here so the PR Opener/Architect does
not propagate stale Refactorer numbers:
- `wc -l` = **416 lines**, not the claimed 412.
- Top-level if/for decision statements = **26**, not the claimed ~13; the
  25→13 delta claim is unverifiable because the script is untracked (no
  pre-refactor version in git history).

None of these affect the gate outcome; recorded as self-report inaccuracy only.

## Equivalent mutants

**None.** No mutation run was performed (mvp skip); no surviving mutants exist
to classify.

## Final test status

Re-run one final time after the skip (Verifier's PASS was independent of these
re-runs; re-confirmed on the exact working-tree state):

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-governance.sh` | 0 | `SYNTAX_OK` |
| `scripts/check-governance.sh` | 0 | 37 PASS lines + `✔ Governance check: every governance requirement verified.` |
| `scripts/check-orchestration.sh` | 0 | `All orchestration references valid.` |
| `make validate-all` | 0 | `All validations passed.` (1 pre-existing WARN: skills/hallmark/SKILL.md 562 lines >500 — unrelated to spec 010) |
| `specs/010-governance-trust-tiers/25-verification.md` present | — | verdict **PASS** |

All green. Stage 5a complete; stage 5b (PR Opener) may proceed.
