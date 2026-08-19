# Mutation Runner Report — spec 025 (direnv model env)

Stage: 5a (Mutation Runner). Branch: `spec/025-direnv-model-env` (nothing committed). `00-informal.md` was not read.

## Verifier's verdict

PASS (carried forward from `specs/025-direnv-model-env/25-verification.md`, verdict at 2026-08-19, all five checks recorded with real execution: scenario traceability, full test suite, complexity gate, design-principles gate, scenario-to-behavior spot check).

## Conformance tier

`mvp`.

Determination: mutation testing is a `production`-tier rule (`docs/CONFORMANCE_TIERS.md` §Tier assignments — "Mutation testing (PiTest / Gremlins / Stryker): production"). This repo is the engineering-standards project — bash/shell scripts + docs, no deployed service, no staging/prod split, no service boundaries — so it does not meet the `production` profile (deployed to a real environment with users). The Verifier's own design-principles gate run records `"tier": "mvp"` in its JSON output. The repo's test surface is the shell selftests; there is no Java/Go/JS-TS production code and no configured mutation toolchain (no `mvn`/PiTest, no `go-mutesting`/`gremlins`, no Stryker config).

## Mutation testing

mutation: skipped — `mvp` tier
command: (none — mutation testing is a `production`-tier gate per docs/SPEC_PIPELINE.md §Conformance tiers; this project declares `mvp`, so the mutation test is skipped by policy, not run)
at: 2026-08-19T14:57:36Z

## Equivalent mutants

None. No mutation run was performed at `mvp` tier, so no mutants were generated and none survived; there are no equivalent mutants to name.

## Complexity summary (carried from the Refactorer, re-recorded by the Verifier in `25-verification.md` §Evidence: complexity gate)

- Gate: `bash scripts/check-code-principles.sh --json` → exit 1.
- 5 FAILs + 17 WARNs, all in `ci/templates/*` files untouched by this spec (`git status` shows no changes under `ci/`).
- Spec-attributable findings: zero — the gate's blame-scoped mode `bash scripts/check-code-principles.sh --json -BaseRef HEAD` → exit 0, `"fails": [], "warns": []`.
- Pre-existing baseline (documented repo precedent: docs/changes/007-verifier-discipline.md §Check 3.5): byte-identical to HEAD, in files this spec does not touch. Flagged to the Architect as a pre-existing remediation item, not a spec-025 defect.

## Final test status (full suite, re-run one final time by the Mutation Runner)

command: bash scripts/model-env.selftest.sh; bash scripts/agent-env.selftest.sh; bash scripts/model-env.runtime-check.sh /tmp/opencode-bin/opencode
exit: 0
at: 2026-08-19T14:57:36Z

```
scripts/model-env.selftest.sh:      selftest: 67 passed, 0 failed  → exit 0
scripts/agent-env.selftest.sh:      selftest: 21 passed, 0 failed  → exit 0
scripts/model-env.runtime-check.sh: runtime-check: 4 passed, 0 failed → exit 0 (pinned opencode binary v1.18.18)
Total: 92 assertions green, all three scripts exit 0.
```

Every acceptance scenario (48/48 AC-025-* sub-IDs, zero dangling) is cited and green; no tests skipped.

## Remediation record

None. No BLOCK occurred during this Mutation Runner run. `25-verification.md` contains no re-verification attempt entries (no phase/attempt counts to carry forward), so per the agent contract the record is `none` rather than a fabricated phase and attempt count. The pre-existing baseline findings (ci/templates complexity FAILs, archived-spec traceability citations) were flagged to the Architect by the Verifier as remediation items, not BLOCKs of this run.
