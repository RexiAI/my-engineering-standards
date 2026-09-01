# 25-verification.md — spec 026 independent re-check

Verifier stage. Re-runs every claim in the tasks/fixes above; records the
exact command, exit code, and raw output for each of the five contract
checks (`docs/SPEC_PIPELINE.md §Audit contract`). This is an
infrastructure/CI spec (no application test suite) — "full test suite" is
interpreted as the full battery of this repo's own self-ci gate scripts,
run directly rather than through CI, against the actual PR branch.

## Evidence: scenario traceability

command: bash scripts/check-scenario-traceability.sh --checks 1
exit: 0
at: 2026-09-01T13:52:00Z

Scenario IDs found: 13

PASS AC-026-01 — traced to a test
PASS AC-026-02 — traced to a test
PASS AC-026-03 — traced to a test
PASS AC-026-04 — traced to a test
PASS AC-026-05 — traced to a test
PASS AC-026-06 — traced to a test
PASS AC-026-07 — traced to a test
PASS AC-026-08 — traced to a test
PASS AC-026-09 — traced to a test
PASS AC-026-10 — traced to a test
PASS AC-026-11 — traced to a test
PASS AC-026-12 — traced to a test
PASS AC-026-13 — traced to a test

✔ Scenario traceability check: every scenario traced, every reference resolves.

Finding (not a blocker, out of scope for spec 026): the unscoped run,
`bash scripts/check-scenario-traceability.sh` (both checks, default `specs`
+ `.`), reports 154 check-2 violations — every one an `AC-024-*`, `AC-025-*`,
`AC-888-88`, `AC-998-*`, or `AC-999-*` string used as an intentionally-fake
ID by other specs' `*.selftest.sh` negative-case fixtures (e.g.
`scripts/check-pr-review.selftest.sh`), not anything this spec touched.
Confirmed via `git worktree` diff against `upstream/main` HEAD
(`21046d96796467f8238d6d613ce3a552bf3fced0`): that check exits 0 there only
because `specs/` does not exist on `main` (specs are archived and deleted at
merge, `docs/SPEC_PIPELINE.md §Archive in the PR`) — so
`scripts/check-scenario-traceability.sh`'s check 2 short-circuits via
`finish_clean` before it ever runs, and has apparently never executed
against this repo's own live tree with a populated `specs/` folder in CI
(`self-ci.yml` only invokes the hermetic `check-scenario-traceability.
selftest.sh`, which scans isolated temp fixtures, never the real repo tree).
This is a latent, repo-wide gate blind spot, unrelated to spec 026's
findings — recommended as a follow-up spec, not fixed here (fixing it would
mean auditing every prior spec's selftest fixtures for a naming collision
with this repo's own real scenario IDs, out of scope for a security
hardening spec). Zero `AC-026-*` IDs appear among the 154.

## Evidence: full test suite

command: bash scripts/check-no-hardcoded-secrets.sh && bash scripts/check-no-hardcoded-secrets.sh --self-test && bash scripts/check-security-hardening.sh && bash scripts/check-security-hardening.sh --self-test && bash scripts/check-model-env.sh && bash scripts/check-gate-consistency.sh && bash scripts/check-orchestration.sh && bash scripts/check-skills.sh && bash scripts/check-ci-sweeper.sh && bash scripts/check-ci-sweeper.sh --self-test && bash scripts/check-pr-review.sh && bash scripts/check-pr-review.selftest.sh && bash scripts/check-loop-triage.sh && make validate-all
exit: 0
at: 2026-09-01T13:53:10Z

PASS check-no-hardcoded-secrets: no hardcoded credential values in agents, commands, scripts, docs, .github, config, templates, ci.
PASS check-no-hardcoded-secrets --self-test: all cases behaved as expected. (4/4 cases: quoted real secret caught, quoted angle-bracket placeholder passes, unquoted YOUR_* passes, widened .github/ scope catches a literal token prefix)
PASS Security hardening check: 27/27 assertions passed (AC-026-01 … AC-026-13, self-citation, self-ci wiring)
PASS check-security-hardening --self-test: baseline (unmodified fixture copy) passes clean; reverted AC-026-05 (StrictHostKeyChecking=no) caught; reverted AC-026-10 (semver-minor auto-merge) caught
PASS check-model-env: all model values are {env:SPEC_*_MODEL} references, no tracked real env files, example wired.
PASS Gate consistency check: PASSED (6 canonical gates, all cross-references consistent)
PASS All orchestration references valid.
PASS All SKILL.md files valid (1 pre-existing warning: skills/hallmark/SKILL.md body >500 lines — unrelated to this spec, unchanged by it).
✔ CI sweeper check: every check passed (26 AC-017-* assertions, unaffected by spec-026's ci-sweeper.yml edits — re-verified after fixing an initial regression, see below).
✔ PR review agent check: every check passed (86 AC-024-* assertions, including the updated AC-024-01-01/03-03/03-07 assertions this spec's T2/T12 required).
✔ Daily Triage loop check: every check passed (unaffected by spec-026's daily-triage.yml install-step edit).
All validations passed. (make validate-all: required-files, cross-references, docs cross-refs, SKILL.md — all clean)

Additional evidence — shell syntax and YAML parse, every changed file:

command: find . -name '*.sh' -not -path './.git/*' -exec bash -n {} \; (0 errors) && for f in .github/workflows/*.yml ci/templates/*.yml; do python3 -c "import yaml; yaml.safe_load(open('$f'))"; done (0 errors)
exit: 0
at: 2026-09-01T13:40:00Z

0 shell parse errors across every .sh file in the repo. 0 YAML parse errors
across every .github/workflows/*.yml and ci/templates/*.yml file (including
the four fully-rewritten files: ci-deploy-ssh.yml, ci-dependabot.yml, and
the edited ci-sweeper.yml / ci-pr-review.yml / ci-toolchain-bump.yml /
daily-triage.yml / pr-review.yml).

Regression found and fixed during this run: the first pass of the
ci-sweeper.yml pwn-request fix (AC-026-01) dropped the literal word "no-op"
from a comment that scripts/check-ci-sweeper.sh's AC-017-03-02 assertion
greps for — check-ci-sweeper.sh FAILed once, was diagnosed, the comment
wording was restored (behavior unchanged, wording only), and check-ci-
sweeper.sh was re-run to confirm 0 FAILs. Same class of regression found
and fixed for check-pr-review.sh's AC-024-01-01 (expected the now-fixed
`mode: subagent`) and AC-024-03-03/03-07/04-02 (expected the now-fixed
`@main` literal) — both updated to assert the corrected, secure behavior
instead of the vulnerable behavior they previously encoded as a requirement.

## Evidence: complexity gate

command: bash scripts/check-code-principles.sh . -BaseRef upstream/main
exit: 0
at: 2026-09-01T13:55:40Z

✔ Design-principles check: 0 FAIL(s), 0 WARN(s).

Note: an unscoped run (`bash scripts/check-code-principles.sh .`, no
-BaseRef) reports 5 pre-existing FAILs, all in `ci/templates/go-saga-lint.go`
and `ci/templates/eslint-saga-rules/saga-compensation.js` — files this spec
did not touch. Confirmed identical between this branch and `upstream/main`
via a side-by-side `git worktree` run (same 5 FAIL lines, byte-identical).
The `-BaseRef` blame-scoped run above is the correct signal for this spec's
own diff and reports 0/0.

## Evidence: design-principles gate

command: bash scripts/check-code-principles.sh . -BaseRef upstream/main
exit: 0
at: 2026-09-01T13:55:40Z

(Same invocation and result as the complexity-gate evidence above — this
script's `-BaseRef` mode evaluates every design-principles category
—complexity, DRY, YAGNI, SOLID, component-per-file, property-tests— in one
pass, blame-scoped to this spec's actual diff.) 0 FAIL(s), 0 WARN(s).

## Evidence: scenario-to-behavior spot check

command: manual read — spot-checking 3 of 13 acceptance scenarios against their fixes
exit: 0
at: 2026-09-01T13:56:00Z

- AC-026-01 (pwn-request guard): `specs/026-ci-security-hardening/20-acceptance/AC-026-01.md`
  asserts the `sweep` job's `if:` includes the fork-origin repository
  comparison and the checkout step carries no `ref:` key. Read
  `.github/workflows/ci-sweeper.yml` lines 51 and 61-62 directly: both hold
  exactly as the scenario describes — not merely a test with the right name,
  the actual condition and the actual absent key.
- AC-026-05/06/07 (deploy hardening): the scenario asserts no
  `StrictHostKeyChecking=no` flag, a validation step ordered before the
  remote-command steps, and a `rm -f ~/.ssh/id_rsa` step with
  `if: always()`. Read `.github/workflows/ci-deploy-ssh.yml` top to bottom:
  the "Validate caller-supplied inputs" step is the third step (after
  checkout), before "Copy compose + nginx config to host" and "Deploy
  service with Docker Compose"; every `ssh`/`scp` call after "Establish
  known_hosts" carries `-o StrictHostKeyChecking=yes`; the final step is
  "Remove SSH private key" with `if: always()`. Matches the scenario.
- AC-026-09 (secrets-gate fix): the scenario asserts a quoted real-looking
  secret is caught and every placeholder form still passes. Re-ran
  `bash scripts/check-no-hardcoded-secrets.sh --self-test` interactively
  (not just via the suite above) and read its four case outcomes line by
  line against the scenario's Given/When/Then — each of the four cases in
  the scenario has a corresponding case in the selftest with the matching
  expected outcome.

No unaccounted behavior found: every file this spec touches maps to a task
in `10-tasks.md` and a scenario in `20-acceptance/`; no incidental change
(e.g. no drive-by refactor of unrelated code) was made outside the
documented findings.

## Verdict

**PASS.** All five contract checks hold: scenario traceability (scoped to
this spec's own 13 IDs — see the check-2 finding above, out of scope,
recorded not fixed), the full self-ci gate battery, the blame-scoped
complexity and design-principles gates, and a manual spot check all confirm
the fixes described in `10-tasks.md` are real, present, and correctly wired
— not self-reported claims taken on faith.
