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
