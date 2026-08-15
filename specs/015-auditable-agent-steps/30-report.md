# Spec 015 — Auditable agent steps — Mutation Runner report

Branch: `spec/015-auditable-agent-steps`. Written from the Verifier's
`25-verification.md` only; `00-informal.md` was not read (information barrier).

## Verifier verdict (carried forward)

PASS — after two fix cycles. Pass 1 FAIL (self-ci step iterated every
`specs/*/` folder, went red on 11 in-flight siblings); Fix 1 (pass 2) iterated
finished specs only but three contract texts still described the old mechanism;
Fix 2 amended `10-tasks.md` Task 4, AC-015-16, and `docs/SPEC_PIPELINE.md` §The
gate to the finished-signal convention. `scripts/check-audit-trail.sh` untouched
throughout (untracked, selftest 13/13 byte-identical across all three passes).
Full re-run at 2026-08-15T18:48Z green on every check attributable to spec 015.

## Mutation score

skipped — mvp tier

```
command: repo conformance tier determination (no AGENTS_<PROJECT>.md at root; gate auto-detects "tier: mvp"; Verifier §7)
exit: 0
at: 2026-08-15T18:49:53Z

Mutation testing is a production-tier gate (docs/SPEC_PIPELINE.md §Conformance
tiers). This repo conforms at mvp tier, so the gate is skipped. The changed code
is a bash check script + markdown prompts/docs + workflow YAML; no mutation
tooling exists for shell in this repo.
```

## Complexity summary (carried from the Refactorer)

`scripts/check-audit-trail.sh` — every function ≤6 decision points under the
established count: check_verifier_evidence 6, selftest 2, main 5, all others
≤3. Confirmed against the unchanged script (Verifier §3 re-ran the count; script
byte-identical since pass 1).

## Equivalent mutants

None.

No mutation tooling ran (mvp tier), so no surviving mutants were produced and no
equivalent mutants exist to name. The script's decision points are all exercised
by `--selftest` (13 assertions covering AC-015-07..14) and the direct
invocations recorded by the Verifier.

## Final test status

Full suite re-run one final time — green.

```
command: bash -n scripts/check-audit-trail.sh && ./scripts/check-audit-trail.sh --selftest && scripts/check-orchestration.sh && make validate-all
exit: 0
at: 2026-08-15T18:49:53Z

bash -n scripts/check-audit-trail.sh          → 0 (parses)
./scripts/check-audit-trail.sh --selftest     → 0, 13 assertions, all PASS
scripts/check-orchestration.sh                → 0, all orchestration references valid
make validate-all                             → 0, all validations passed
  (1 WARN on skills/hallmark/SKILL.md — pre-existing, unrelated)

Expected mid-pipeline state (not a suite failure):
./scripts/check-audit-trail.sh 015-auditable-agent-steps → 1, only
"missing 30-report.md (AC-015-12)" — this report is that artifact; the gate's
five evidence-block checks all PASS. Re-run after this report is written
confirms the folder complete.
```

This repo has no unit-test suite (Makefile targets: validate, validate-docs,
validate-refs, validate-skills, validate-all, lint, format, stats — no test
target). The shipped shell check `scripts/check-audit-trail.sh` is spec 015's
test carrier; its `--selftest` exercises every acceptance scenario
(AC-015-07..14), re-confirmed above.
