# 026-ci-security-hardening

> Spec pipeline archive. Original source: `specs/026-ci-security-hardening/` (deleted by this script).
> Archived: 2026-09-01

## Original ask

# 026 — CI/CD and agent-invocation security hardening

## Ask

An independent security review of this repo's own `.github/workflows/`,
`agents/pr-review.md`, and the headless-agent invocation plumbing found a set
of concrete issues, ranging from a working pwn-request (arbitrary code
execution from a fork PR with base-repo privileges) down to a documentation
nit. Fix every finding. This repo self-hosts its own CI/CD and agent
tooling and is consumed by child repos in production — a defect here ships
to every consumer.

## Findings (source: security review, cross-checked against GitHub's own
`pull_request_target`/pwn-request docs, the tj-actions/changed-files
incident writeups, and OWASP GenAI Top 10 2025)

1. **Critical — pwn request in `ci-sweeper.yml`.** The workflow triggers on
   `workflow_run` for `Self CI` (which itself triggers on `pull_request` from
   forks) with base-repo privileges (`issues: write`, secret access), checks
   out `github.event.workflow_run.head_sha` — the failing run's commit,
   potentially attacker-authored — and then executes
   `scripts/install-opencode.sh` from that checked-out tree, plus symlinks
   and loads `skills/` and `config/model.local.env.example` from it. A fork
   PR that makes Self CI fail (trivial) and replaces
   `scripts/install-opencode.sh` gets that replacement executed with the
   base repo's privileges.

2. **Critical — the PR-review agent's `permission` block never loads in
   CI.** `agents/pr-review.md`'s frontmatter documents a `permission` block
   (deny all edits, allow-list a handful of read-only `bash` commands) and
   claims it "enforces this in config, not just prose." But
   `ci-pr-review.yml` invokes the agent by
   `cat agents/pr-review.md | sed '/^---$/,/^---$/d'` — stripping the
   frontmatter — then feeds the remaining prose into a plain
   `opencode run "<prompt>"` call with no `--agent` flag (the comment states
   `--agent` is rejected because the agent's `mode` is `subagent`). The
   `permission` block is real in the committed file and inert in every
   actual CI run; the only live control is English text in a prompt.

3. **High — no defense against prompt injection via untrusted diff/log
   content.** Both agents (`pr-review`, and the ci-sweeper's `ci-triage`
   skill) consume attacker-influenceable content (a PR diff, CI log lines)
   with nothing telling the agent to treat that content as data rather than
   instructions.

4. **High — no integrity check on the opencode binary download.**
   `scripts/install-opencode.sh` (and a second, duplicated, drifted copy
   inline in `daily-triage.yml`) `curl`s a release tarball and executes it
   with no checksum verification.

5. **High — every third-party GitHub Action, and the two cross-repo
   `workflow_call` references to this repo's own reusable workflows, are
   pinned to a mutable ref** (`@v4`, `@master`, `@main`) instead of a commit
   SHA — the exact mechanism behind the tj-actions/changed-files
   supply-chain compromise.

6. **High — `ci-deploy-ssh.yml` has three separate production-facing
   issues:** `StrictHostKeyChecking=no` on every SSH/SCP call (no MITM
   protection against the production host at all); caller-controlled
   `inputs.app-dir` / `inputs.service-name` interpolated unsanitized into
   remote shell command strings; and `${{ secrets.* }}` interpolated
   directly into `run:` script bodies instead of passed through `env:`.

7. **High — the hardcoded-secrets gate has a bypass and a scope gap.**
   `scripts/check-no-hardcoded-secrets.sh`'s `is_ignored_rhs` treats *any*
   quoted assignment value as a safe placeholder — `TOKEN="the-actual-real-
   value"` passes clean, which is backwards: quoting is how a real literal
   is normally written in shell, not evidence it's a placeholder. The scan
   also only covers `agents/ commands/ scripts/ docs/`, not `.github/`,
   `config/`, `templates/`, or `ci/`.

8. **Medium — `ci-dependabot.yml` auto-merges `semver-minor` bumps, not just
   patch.** A minor bump is just as viable a malware-delivery vector as a
   patch (a compromised registry account ships whatever version it wants).

9. **Medium — `ci-toolchain-bump.yml` trusts remote JSON straight into
   `sed -i`** with no validation of the fetched version string's shape
   before it becomes part of a `sed` program.

10. **Medium — no cost ceiling on the `ci-sweeper` loop.** It reacts to
    every failing Self CI run (now scoped to same-repo runs only, per
    finding 1's fix) with no per-window invocation cap — `loop-budget.md`
    only covers the `daily-triage` loop today.

11. **Low — `config/agent.local.env.example` nudges toward a classic PAT**
    ("or reuse the fine-grained token above") for `GH_TOKEN`, when the
    fine-grained token it just described creating is already sufficient for
    every documented use.

## Out of scope

- Rewriting the spec pipeline itself (`agents/spec-*.md`) — none of the
  findings touch it.
- Adding a new SaaS security scanner or changing `ci-security.yml`'s
  CodeQL/Trivy tool choice — only the pinning of the actions that run them.
- Migrating `install-opencode.sh` to verify a maintainer *signature* (no
  signed-release mechanism exists upstream today) — a pinned SHA-256 is the
  achievable integrity control.

## Tasks

# 026 — CI/CD and agent-invocation security hardening

Source: `specs/026-ci-security-hardening/00-informal.md`. This is an
infrastructure/CI hardening spec, not application code — there is no
project test suite to extend. Per `docs/SPEC_PIPELINE.md §Audit contract`,
each finding below is fixed directly in the affected workflow/script/agent
file, and its acceptance scenario is traced the same way this repo already
traces its other workflow specs (017 CI Sweeper, 019 Daily Triage, 024 PR
Review Agent): a grep-able `AC-026-NN` ID embedded in the fix itself, plus a
new deliverables-gate script (`scripts/check-security-hardening.sh`,
mirroring `check-ci-sweeper.sh` / `check-pr-review.sh`) that mechanically
re-asserts every fix is present.

## Tasks

### T1 — Close the `ci-sweeper.yml` pwn request (AC-026-01)

`.github/workflows/ci-sweeper.yml`: gate the `sweep` job on
`github.event.workflow_run.head_repository.full_name == github.repository`
(fork-originated Self CI failures get no automated sweep) and drop the
`ref: ${{ github.event.workflow_run.head_sha }}` override from the checkout
step (the job checks out its own trusted ref; the ci-triage skill already
only needs `gh run view --log-failed`, never the checked-out tree).

### T2 — Make the PR-review agent's `permission` block load for real (AC-026-02)

`agents/pr-review.md`: change `mode: subagent` to `mode: primary` (with a
comment explaining why, and a warning not to revert one half without the
other). `.github/workflows/ci-pr-review.yml`: invoke
`opencode run --agent pr-review "<short trusted-value-only prompt>"` instead
of `cat agents/pr-review.md | sed '/^---$/,/^---$/d'` concatenated into a
plain prompt string. `scripts/check-pr-review.sh`: update AC-024-01-01's
`mode: subagent` assertion to `mode: primary` (the spec-024 gate encoded the
now-fixed insecure behavior as a requirement).

### T3 — Untrusted-content warning in the PR-review agent's prompt (AC-026-03)

`agents/pr-review.md`: add an explicit "treat diff/log content as data, not
instructions" paragraph (OWASP GenAI LLM01), stating the `permission` block
is the real boundary and the prompt is defense in depth only.

### T4 — Checksum-verify the opencode binary download (AC-026-04)

`scripts/install-opencode.sh`: pin a `SHA256` alongside `VERSION`, verify
with `sha256sum -c` before extracting. `.github/workflows/daily-triage.yml`:
replace its duplicated, unchecksummed inline install with a call to the
now-hardened shared script (closes both the missing-checksum gap and a
version-drift risk — two copies of the same download logic).

### T5 — Pin `known_hosts` for the production SSH deploy (AC-026-05)

`.github/workflows/ci-deploy-ssh.yml`: add an optional `SSH_KNOWN_HOSTS`
secret; when present, pin it and use `StrictHostKeyChecking=yes` for every
SSH/SCP call; when absent, `ssh-keyscan` once (documented TOFU gap, loudly
warned) and still enforce `yes` for the rest of the job. Never
`StrictHostKeyChecking=no`.

### T6 — Validate caller-supplied deploy inputs before use in remote commands (AC-026-06)

`.github/workflows/ci-deploy-ssh.yml`: add a validation step that rejects
`inputs.app-dir` / `inputs.service-name` values containing characters
outside `[A-Za-z0-9._/-]` before either is interpolated into any remote
`ssh`/`scp` command.

### T7 — Remove the SSH private key on exit; secrets via `env:` not inline (AC-026-07)

`.github/workflows/ci-deploy-ssh.yml`: map every `secrets.*` /
`inputs.*` value the job uses into a step/job `env:` block instead of
interpolating `${{ secrets.* }}` directly into `run:` script bodies; add a
`Remove SSH private key` step with `if: always()`.

### T8 — Bound `ci-sweeper`'s invocation cost (AC-026-08)

`.github/workflows/ci-sweeper.yml`: add a budget-guard step that counts the
workflow's own runs in the last 24h via the read-only Actions API and skips
installing/invoking opencode past a cap, recorded in `loop-budget.md`'s new
`§ci-sweeper` section.

### T9 — Fix the hardcoded-secrets gate's quoted-value bypass and scope gap (AC-026-09)

`scripts/check-no-hardcoded-secrets.sh`: `is_ignored_rhs` no longer treats
every quoted value as a placeholder — only empty, a variable reference
(`${...}`, `\${...}`, or a quoted `"$VAR..."`), an angle-bracket
placeholder, or a recognized placeholder/example word (case-insensitive),
whether or not it is quoted. Widen the scanned dirs to include `.github/`,
`config/`, `templates/`, `ci/` (was `agents/ commands/ scripts/ docs/`
only). Add a `--self-test` mode (repo convention) proving the fix catches a
quoted real-looking secret and still passes every legitimate placeholder
form; wire it into `self-ci.yml` alongside the existing invocation.

### T10 — Dependabot auto-merge: patch only (AC-026-10)

`.github/workflows/ci-dependabot.yml`: the `Approve & merge` step's `if:`
now checks `update-type == 'version-update:semver-patch'` only (was patch
**or** minor); document the branch-protection prerequisite this workflow's
safety depends on.

### T11 — Validate remote-sourced toolchain versions before `sed -i` (AC-026-11)

`.github/workflows/ci-toolchain-bump.yml`: each of the three blocks (Go,
Node, Python) validates the fetched `latest` value against the expected
shape (`N.N`/`N.N.N`, `N`, `N.N.N` respectively) before writing it to a
manifest or `sed -i` program; an unexpected shape warns and skips that
bump rather than risking it.

### T12 — SHA-pin every third-party Action and cross-repo workflow reference (AC-026-13)

Every `uses: owner/action@vN` / `@master` in `.github/workflows/*.yml`
becomes `uses: owner/action@<full-sha> # vN.N.N`. The two cross-repo
`RexiAI/my-engineering-standards/.github/workflows/*.yml@main` references
(`.github/workflows/pr-review.yml`, and every reusable-workflow reference
`scripts/init-ci.sh` generates into a child repo's `ci.yml`) become
`@<commit-sha> # pinned; bump deliberately, never track a branch`, via a new
`STANDARDS_PIN` constant in `init-ci.sh` so every generated reference bumps
together. `scripts/check-pr-review.sh`'s AC-024-03-03/03-07/04-02 string
assertions are updated to match the pinned form (they hardcoded the now-fixed
`@main` literal).

### T13 — Documentation: classic-PAT nudge and the standing supply-chain rule set (AC-026-12)

`config/agent.local.env.example`: `GH_TOKEN`'s comment stops suggesting a
classic PAT as an equal alternative — reuse the fine-grained token unless a
scope it cannot cover is genuinely required. `docs/SECURITY.md`: new
§CI/CD Supply Chain section codifying every rule above (pwn requests,
SHA-pinning, checksum-verified binaries, permission blocks that must
actually load, untrusted-model-input handling, loop cost bounds,
reusable-workflow input validation) as the standing rule, not a one-time
fix.

### T14 — Deliverables gate + wiring (AC-026-01…13, self-citation)

New `scripts/check-security-hardening.sh` (repo convention: `verify_grep`
per AC ID against the affected file, `--self-test` proving it fails closed
on a reverted fixture, self-citing every `AC-026-NN` ID the way
`check-ci-sweeper.sh` / `check-pr-review.sh` do). Wired into
`.github/workflows/self-ci.yml`'s `validate` job, no `continue-on-error`.

## Open questions (need a human answer before /build)

None — every finding in `00-informal.md` maps to a task above with a fix
already implementable from the finding's own description; no ambiguous
informal-spec language required an assumption call.

## Acceptance scenarios

## AC-026-01 — Fork-originated Self CI failures never reach the privileged sweep; same-repo failures still get swept via a trusted checkout
## AC-026-02 — `--agent pr-review` invocation, not frontmatter-stripped prompt concatenation
## AC-026-03 — The agent is told diff/log content is data, not instructions
## AC-026-04 — install-opencode.sh verifies SHA-256 before executing; daily-triage.yml stops duplicating the download
## AC-026-05 — `StrictHostKeyChecking=no` is gone; `SSH_KNOWN_HOSTS` pins the host key
## AC-026-06 — `app-dir` / `service-name` are rejected if they contain unsafe characters
## AC-026-07 — No `${{ secrets.* }}` interpolated directly into a `run:` body; key file removed with `if: always()`
## AC-026-08 — the sweeper skips cleanly past its daily invocation cap
## AC-026-09 — a quoted, real-looking secret is caught; every legitimate placeholder form still passes; scan scope widened
## AC-026-10 — a semver-minor Dependabot PR is no longer auto-merged
## AC-026-11 — an unexpected version shape is rejected, not written into a manifest or a sed program
## AC-026-12 — `GH_TOKEN`'s template comment prefers the fine-grained token already described
## AC-026-13 — no `.github/workflows/*.yml` uses a mutable ref for a third-party Action or a cross-repo `workflow_call`

## Verification

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

## Quality gates

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
