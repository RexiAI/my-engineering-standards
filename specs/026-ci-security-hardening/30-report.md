# 30-report.md — spec 026 final report

## Summary

Security review of this repo's own `.github/workflows/`, `agents/pr-review.md`,
and headless-agent invocation plumbing found 13 issues, from a working
pwn-request (arbitrary code execution from a fork PR with base-repo
privileges) to a documentation nit. All 13 fixed. 42 files changed
(1136 insertions, 257 deletions) outside `specs/`, plus this spec folder.

## Findings fixed (see `00-informal.md` for full detail, `20-acceptance/` for scenarios)

| # | Severity | Finding | Fix |
|---|---|---|---|
| AC-026-01 | Critical | `ci-sweeper.yml` pwn request: fork-authored commit executed with base-repo privileges | Fork-origin job guard + no `ref:` override on checkout |
| AC-026-02 | Critical | `pr-review` agent's `permission` block stripped before every real invocation | `mode: primary` + `--agent pr-review` invocation |
| AC-026-03 | High | No prompt-injection defense for diff/log content | Explicit untrusted-content warning in the agent |
| AC-026-04 | High | opencode binary downloaded with no integrity check | SHA-256 pin + `sha256sum -c`; daily-triage deduped onto the shared script |
| AC-026-05 | High | `StrictHostKeyChecking=no` on the production deploy | Optional `SSH_KNOWN_HOSTS` secret, `=yes` everywhere |
| AC-026-06 | High | Caller-controlled deploy inputs unsanitized in remote commands | Charset validation before any remote command |
| AC-026-07 | High | Secrets interpolated into `run:` bodies; key left on disk | `env:` mapping everywhere; key removed `if: always()` |
| AC-026-08 | Medium | No cost ceiling on the sweeper loop | 24h invocation-count budget guard, documented in `loop-budget.md` |
| AC-026-09 | High | Hardcoded-secrets gate: quoted values auto-exempted; scope gap | Quoting no longer exempts; scope widened to `.github/ config/ templates/ ci/` |
| AC-026-10 | Medium | Dependabot auto-merged semver-minor, not just patch | Patch-only |
| AC-026-11 | Medium | Remote JSON trusted straight into `sed -i` | Shape-validated before use |
| AC-026-12 | Low | Doc nudged toward a classic PAT | Reuse fine-grained token by default |
| AC-026-13 | High | Every third-party Action / cross-repo workflow ref on a mutable tag/branch | SHA-pinned everywhere (workflows, `init-ci.sh`, `init-deploy.sh`, `ci/templates/*`, consumer docs) |

Plus: a new standing rule set in `docs/SECURITY.md §CI/CD Supply Chain`
codifying all of the above so the next workflow or agent invocation this
repo adds is reviewed against the same checklist, not just this one-time
fix.

## Regressions found and fixed during this spec's own verification

Fixing AC-026-01, AC-026-02, and AC-026-13 changed behavior that three
existing spec-024/017 deliverables-gate scripts asserted as *required*
(because those assertions encoded the vulnerable behavior itself — literal
`mode: subagent`, literal `@main`, and a wording match that happened to sit
next to the vulnerable `ref:` line). Each was caught by re-running the
existing gate suite, diagnosed, and fixed in the gate script itself (never
by reverting the security fix to satisfy a stale assertion):

- `scripts/check-ci-sweeper.sh` (AC-017-03-02): required the literal word
  "no-op" in a comment my first pass reworded away. Restored the word
  (wording only, behavior unchanged), re-ran, confirmed 0 FAIL.
- `scripts/check-pr-review.sh` (AC-024-01-01, AC-024-03-03, AC-024-03-07,
  AC-024-04-02): required `mode: subagent` and the literal `@main` string —
  both are the exact vulnerabilities AC-026-02 and AC-026-13 fix. Updated
  the assertions to the corrected values (`mode: primary`, the SHA-pinned
  reference) so the gate now encodes the secure behavior as the requirement.

## Mutation testing

Not applicable in the sense this repo's `spec-mutation-runner` agent
performs it (PiTest/Gremlins/Stryker against application source under
`src/`/equivalent) — this spec has no such tree; every fix lives in
`.github/workflows/*.yml`, `agents/*.md`, and `scripts/*.sh`. The equivalent
mutation-resistance evidence for an infra spec of this kind is the
deliverables gate's own `--self-test` mode, which builds a fixture, reverts
a fix, and asserts the gate catches the regression — the same role a killed
mutant plays for application code. Two such self-tests exist and both pass:

- `scripts/check-no-hardcoded-secrets.sh --self-test` — 4/4 cases pass
  (quoted real secret caught, three placeholder forms still pass).
- `scripts/check-security-hardening.sh --self-test` — baseline passes,
  and both of its two independent reverted-fix cases (AC-026-05, AC-026-10)
  are caught.

**Mutation-equivalent status: GREEN** — 6/6 negative-case assertions across
the two selftests behave as expected; no case passed when it should have
failed, no case failed when it should have passed.

## Complexity / design-principles

`bash scripts/check-code-principles.sh . -BaseRef upstream/main`: 0 FAIL(s),
0 WARN(s) — blame-scoped to this spec's actual diff. (An unscoped run
reports 5 pre-existing FAILs in files this spec did not touch,
`ci/templates/go-saga-lint.go` and
`ci/templates/eslint-saga-rules/saga-compensation.js`, confirmed identical
on `upstream/main`.)

## Final test status

GREEN. See `25-verification.md` for the full evidence log: every self-ci
gate script re-run directly (not just via CI), 0 shell-syntax errors across
every `.sh` file in the repo, 0 YAML-parse errors across every changed
workflow/template file, `make validate-all` clean, and a live
`scripts/init-ci.sh --with-pr-review --with-release --with-deploy` scratch
generation confirmed to emit zero `@main` references.

## Known out-of-scope finding (not fixed, recommended follow-up)

`scripts/check-scenario-traceability.sh`'s check 2 (dangling test
references) has apparently never executed against this repo's own live
tree in CI — `self-ci.yml` only runs the hermetic
`check-scenario-traceability.selftest.sh` against isolated fixtures. Running
it directly (as this spec's own Verifier stage did, to check AC-026-*'s
traceability) surfaces 154 pre-existing dangling `AC-024-*`/`AC-025-*`/
`AC-888-88`/`AC-998-*`/`AC-999-*` references — all intentionally-fake IDs
used by other specs' own `*.selftest.sh` negative-case fixtures, none
touched by this spec. Recommend a follow-up spec that either wires
`check-scenario-traceability.sh` (not just its selftest) into `self-ci.yml`
when a `specs/` folder is present, or renames those fixture IDs out of the
real `AC-NNN-NN` namespace so they can never collide.

PR: (appended by the PR Opener stage after this branch is pushed and the PR
is opened)
