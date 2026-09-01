# 25-verification.md — spec 027 independent re-check

## Evidence: scenario traceability

command: bash scripts/check-scenario-traceability.sh
exit: 0
at: 2026-09-01T14:38:00Z

Scenario IDs found: 2

PASS AC-027-01 — traced to a test
PASS AC-027-02 — traced to a test

✔ Scenario traceability check: every scenario traced, every reference resolves.

This is the live-tree run this spec itself wires into self-ci (T3) —
running it here, against the real repo tree with specs/027 in flight, both
of this spec's own scenarios trace cleanly, proving T3's claim by using the
exact mechanism T3 adds.

Additional evidence — reproduction of the original 154-violation state,
confirmed fixed: checked out spec 026's PR branch at commit `1a5fcdf`
(before archival, `specs/026-ci-security-hardening/` still present, every
other spec's gate-script self-citations for already-archived numbers
17/19/24/25 present in `scripts/`) in a scratch worktree, copied this
spec's fixed `scripts/check-scenario-traceability.sh` into it, and ran it
with no arguments:

command: git worktree add /tmp/repro 1a5fcdf && cp scripts/check-scenario-traceability.sh /tmp/repro/scripts/ && (cd /tmp/repro && bash scripts/check-scenario-traceability.sh)
exit: 0
at: 2026-09-01T14:20:00Z

Scenario IDs found: 13
[... 13 PASS lines, AC-026-01 through AC-026-13 ...]
✔ Scenario traceability check: every scenario traced, every reference resolves.

0 violations, down from the unfixed script's 154 violations against the
byte-identical tree (same commit, only the checker script differs).

## Evidence: full test suite

command: bash scripts/check-scenario-traceability.selftest.sh && bash scripts/check-ci-sweeper.sh && bash scripts/check-pr-review.sh && bash scripts/check-pr-review.selftest.sh && bash scripts/check-security-hardening.sh && bash scripts/check-security-hardening.sh --self-test && bash scripts/check-no-hardcoded-secrets.sh && bash scripts/check-model-env.sh && bash scripts/check-gate-consistency.sh && bash scripts/check-orchestration.sh && bash scripts/check-skills.sh && bash scripts/check-loop-triage.sh && make validate-all
exit: 0
at: 2026-09-01T14:42:00Z

✔ check-scenario-traceability selftest: 4 cases passed (pass, orphan, dangle,
  out_of_flight — the new case this spec adds).
✔ CI sweeper check: every check passed (unaffected — spec 026's ci-sweeper.yml
  fixes are untouched by this spec).
✔ PR review agent check: every check passed (unaffected).
✔ Security hardening check: every check passed (unaffected — this spec
  touches only check-scenario-traceability.sh, its selftest, and
  self-ci.yml; scripts/check-security-hardening.sh's own 27 assertions
  about spec 026's fixes are all still true).
✔ check-security-hardening --self-test: baseline passes, both reverted-fix
  cases still caught (proves this spec introduced no regression in spec
  026's own fixes).
✔ check-no-hardcoded-secrets: clean.
✔ check-model-env, check-gate-consistency, check-orchestration, check-skills,
  check-loop-triage: all clean, all unaffected.
✔ make validate-all: all validations passed.

Additional evidence — shell syntax and YAML parse:

command: bash -n scripts/check-scenario-traceability.sh && bash -n scripts/check-scenario-traceability.selftest.sh && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/self-ci.yml'))"
exit: 0
at: 2026-09-01T14:39:00Z

Both scripts parse; self-ci.yml parses as valid YAML after the new step.

## Evidence: complexity gate

command: bash scripts/check-code-principles.sh . -BaseRef upstream/main
exit: 0
at: 2026-09-01T14:43:00Z

✔ Design-principles check: 0 FAIL(s), 0 WARN(s). Blame-scoped to the
combined diff of specs 026 and 027 (both land in this PR) against
`upstream/main` — no new complexity/duplication/SOLID/component-per-file
violation from either spec's changes.

## Evidence: design-principles gate

command: bash scripts/check-code-principles.sh . -BaseRef upstream/main
exit: 0
at: 2026-09-01T14:43:00Z

(Same invocation and result as the complexity-gate evidence above.)

## Evidence: scenario-to-behavior spot check

command: manual read — both AC-027-NN scenarios against the actual fix
exit: 0
at: 2026-09-01T14:44:00Z

- AC-027-01: read `scripts/check-scenario-traceability.sh`'s check-2 block
  directly — `IN_FLIGHT_NUMS` is computed from `"$SPECS_DIR"/*/` directory
  basenames matching `[0-9][0-9][0-9]-*` before the check-2 loop, and the
  loop's `case " $IN_FLIGHT_NUMS " in ... continue ;; esac` skips any
  referenced ID whose number is not in that set before it ever reaches the
  `SCENARIO_IDS` membership test. Matches the scenario exactly — not just a
  test with the right name, the actual control-flow guard.
- AC-027-02: read `.github/workflows/self-ci.yml` directly — the new step
  is `run: bash scripts/check-scenario-traceability.sh`, no positional
  arguments, no `continue-on-error`, placed immediately after "Run gate
  selftests". Matches the scenario.

No unaccounted behavior found: this spec touches exactly three files
(`scripts/check-scenario-traceability.sh`,
`scripts/check-scenario-traceability.selftest.sh`,
`.github/workflows/self-ci.yml`) — every line changed maps to T1, T2, or T3
in `10-tasks.md`.

## Verdict

**PASS.** All five contract checks hold, including a direct reproduction
of the original 154-violation state (spec 026's own PR branch before
archival) confirming the fix actually resolves the exact real-world
condition it was written for, not just a synthetic fixture.
