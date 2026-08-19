# 024-pr-review-agent

> Spec pipeline archive. Original source: `specs/024-pr-review-agent/` (deleted by this script).
> Archived: 2026-08-19

## Original ask

# 023 — Self-hosted PR review agent (review + suggest fixes only)

A self-hosted PR review agent, in the spirit of The-PR-Agent/pr-agent, that
reviews every pull request on this repo **and child repos** — finds bugs,
suggests fixes, comments inline. It never merges, never pushes, never rewrites
the PR. Scope is intentionally narrow: **review + suggest fixes only** (no
describe, no improve, no auto-apply, no title/summary editing).

The user's intent: "I want to use a PR agent like this project to recheck my
code each PR" — a reviewer of record in CI, not an author.

## What it must provide

1. **Trigger.** GitHub Actions on `pull_request` (opened, ready_for_review,
   synchronize, reopened) for this repo. Runs the agent in CI, posts review
   comments to the PR.

2. **Scope lock: review + suggest fixes only.** The agent's sole job is to
   review the diff and produce findings with concrete suggested fixes.
   Explicitly disabled: PR description generation (describe), auto-improve
   (improve), ask-the-PR, title/summary rewriting, auto-merge, pushing commits.
   This is enforced in the agent's config, not just its prompt.

3. **Model: `opencode-go/kimi-k3` only.** The PR review agent uses Kimi K3 via
   the OpenCode Zen endpoint (`https://opencode.ai/zen/go/v1`), authenticated with
   `OPENCODE_API_KEY`. No other model is used by this agent. The model id is
   pinned in the agent config.

4. **Self-hosted.** Runs on this repo's own CI (GitHub-hosted or self-hosted
   runner) — no SaaS reviewer (CodeRabbit et al.), no external service holding
   the repo's code.

5. **Child-repo opt-in.** A shared workflow in this standards repo (e.g.
   `.github/workflows/shared/pr-review.yml`) that child repos reference, plus a
   one-command opt-in via `scripts/init-ci.sh` (new flag) that wires the shared
   workflow + the required `OPENCODE_API_KEY` secret into the child repo's CI.
   Matches how `init-ci.sh --with-release` already propagates semantic-release.

6. **Review discipline.** Findings are grounded in the diff + the repo's own
   standards (`docs/CODING_CONVENTIONS.md`, per-language `language-specific/`,
   AGENTS.md rules). Each finding: file:line, what's wrong, why, suggested fix.
   No cosmetic nitpicking that drowns real issues — findings must be
   actionable. No false-positive "security" findings without evidence.

7. **Security boundary.** Read-only review scope. The agent needs read access to
   the repo + permission to comment on PRs, and **nothing else**. `OPENCODE_API_KEY`
   comes from a GitHub secret, never a committed file. Fits the existing
   `docs/SECURITY.md §Secrets Management` rules.

8. **Bounded cost.** The review runs once per relevant PR event (debounced:
   review only the latest head on synchronize — no re-review per trivial push
   unless the diff changed meaningfully), early-exits when CI is green and the
   PR is untouched. Cost guidance documented, consistent with the CI-sweeper's
   "early exit when green" rule.

## Acceptance criteria

- AC-001: a shared workflow `.github/workflows/shared/pr-review.yml` exists in
  this standards repo that runs the PR review agent on PRs, comment-only.
- AC-002: the agent is scoped to review + suggest fixes only — describe,
  improve, auto-apply, title/summary editing, and merge are disabled in config.
- AC-003: the review agent's model is pinned to `opencode-go/kimi-k3`; the
  endpoint is `https://opencode.ai/zen/go/v1`; auth is `OPENCODE_API_KEY`.
- AC-004: `scripts/init-ci.sh` gains an opt-in flag (e.g. `--with-pr-review`)
  that wires the shared workflow + the `OPENCODE_API_KEY` secret into a child
  repo, mirroring `--with-release`.
- AC-005: the workflow works on this repo itself (self-hosting proof) with the
  key supplied via GitHub secret; a run with no key skips cleanly and never
  fails the PR's required checks.
- AC-006: documented in `docs/CI_CD.md` (and cross-referenced from
  `docs/SPEC_PIPELINE.md §Using OpenCode Zen`) — scope lock, model, secret
  handling, child-repo opt-in, cost/bounds.

## Out of scope (explicitly not this spec)

- Auto-merge, auto-push, auto-edit, Dependabot-style fix PRs.
- Multi-model routing for the reviewer (kimi-k3 only).
- SaaS reviewer integration.
- Extending the spec-pipeline agents (Specifier/Coder/etc.) — this is a
  separate, PR-time reviewer, not part of `/spec` or `/build`.

## Tasks

# 023 — Self-hosted PR review agent (review + suggest fixes only)

Source: `specs/023-pr-review-agent/00-informal.md`. Scope lock: **review + suggest fixes only**.
Out of scope (per §Out of scope): auto-merge, auto-push, auto-edit, Dependabot-style fix PRs,
multi-model routing, SaaS reviewer integration, extending the spec-pipeline agents.

Repo ground truth this task list builds on (read before implementing):

- Shared reusable workflows live in `.github/workflows/shared/` (e.g. `ci-release.yml`); consumers wrap them in a small top-level workflow with its own `on:` triggers (see the `ci-toolchain-bump` consumer pattern in `docs/CI_CD.md §Toolchain Versions`).
- `scripts/init-ci.sh` already implements `--with-release` (spec 022): flag var, `case` parse, usage line, secret prompt gated on the flag, `_gh_release_job` emitting the job into `ci.yml`, summary notes, and a byte-compatible default when the flag is absent (regression guard AC-022-03-03). `--with-pr-review` must mirror this structure.
- The repo's pinned opencode binary comes from `scripts/install-opencode.sh`; headless CI invocation precedent is `.github/workflows/ci-sweeper.yml` (checkout with `persist-credentials: false`, install pinned binary, make skills/agents discoverable under `.opencode/`, `opencode run --print-logs`, never `--auto`).
- Agent configs are markdown files in `agents/` with frontmatter (`description`, `mode`, `permission`, and — for this agent only — a literal `model:` pin; see `agents/spec-specifier.md` for the frontmatter shape). `specs/*/00-informal.md` is the only spec-pipeline info barrier; this agent is a separate, PR-time reviewer and is **not** a `spec-*` agent.
- `scripts/check-model-env.sh` requires every `agent.*.model` in `opencode.json` to be an `{env:SPEC_*_MODEL}` reference — so the kimi-k3 pin must live in the agent file's frontmatter, and the Zen provider config (endpoint + auth) must live in an `opencode.json` `provider` block, not in the `agent` block.
- Secret rule: `docs/SECURITY.md §Secrets Management` — never commit secrets; `OPENCODE_API_KEY` arrives via a GitHub secret and only the secret name appears in committed files (`scripts/check-no-hardcoded-secrets.sh` scans `agents/`, `commands/`, `scripts/`, `docs/`).

## Open questions (need a human answer before /build)

1. **SPEC_PIPELINE.md has no "Using OpenCode Zen" section today.** AC-006 requires a cross-reference *from* `docs/SPEC_PIPELINE.md §Using OpenCode Zen`. Assumption in T5: add a short "Using OpenCode Zen" section to `docs/SPEC_PIPELINE.md` (model + endpoint + auth + pointer to the new CI_CD.md section). Confirm, or tell the Coder to place the cross-reference inside the existing `§Model configuration` instead.
2. **Endpoint value.** AC-003 pins `https://opencode.ai/zen/go/v1`. The repo's existing provider precedent (`docs/changes/019-daily-triage-loop.md`) uses `https://opencode.ai/zen/go/v1` for the `opencode-go` provider. T1 uses exactly the AC-003 value. Confirm `https://opencode.ai/zen/go/v1` is the correct base URL for the pr-review agent.
3. **"Early-exits when CI is green and the PR is untouched"** (informal item 8) is ambiguous. Interpretation used in T2: skip the model run when (a) the head SHA was already reviewed — a `Reviewed-SHA:` marker in the agent's previous comment matches the current head — **and** (b) all CI check buckets for that head pass. "Review only the latest head on synchronize" is handled by a per-PR `concurrency` group with `cancel-in-progress: true` in the caller workflow (T3). "No re-review per trivial push unless the diff changed meaningfully" is implemented as "no re-review when the head SHA is unchanged"; a semantic notion of "meaningful diff" is not defined anywhere and is **not** implemented. Confirm.
4. **GitLab platform.** The shared workflow is GitHub Actions-only. `--with-pr-review` emits the job only for `--platform github|both`; on `--platform gitlab` it prints a warning and emits nothing. Confirm this no-op boundary (mirrors how `--with-release` is GitHub+GitLab, but PR review has no GitLab template).
5. **No deliverables gate script.** The repo convention for workflow specs is a check script wired into self-ci's `validate` job (`check-ci-sweeper.sh`, `check-loop-triage.sh`, `check-pr-babysitter.sh`). The informal spec does not ask for one, so no task below ships one — but the convention strongly suggests it. Add a `scripts/check-pr-review.sh` + self-ci step, or keep the spec minimal?

---

## T1 — PR review agent config: model pin, Zen endpoint, scope lock, review discipline

Create `agents/pr-review.md` (a new standalone agent — no `spec-*` agent is modified) and wire
the OpenCode Zen provider so the pinned model resolves.

What the task must do:

- `agents/pr-review.md` with frontmatter: `description`, `mode: subagent`, and a **literal**
  `model: opencode-go/kimi-k3` (pinned in the agent config per the informal spec — no
  `{env:...}` indirection; this is the one deliberate exception to the "agents ship without
  `model:`" convention in `docs/SPEC_PIPELINE.md §Model configuration`).
- `permission` block enforcing the scope lock **in config, not just the prompt**: `edit`
  denied for all paths; `bash` allow-list restricted to read-only `gh`/`git` commands needed
  to read the PR/diff and post a review comment; no allowed command can write files, commit,
  push, merge, or edit PR metadata.
- Prompt body with: (a) the scope lock — review + suggest fixes only; **explicitly forbidden
  as literal text**: PR description generation (describe), auto-improve (improve), auto-apply
  of suggestions, title/summary rewriting, auto-merge, pushing commits; (b) review discipline —
  every finding carries `file:line`, what's wrong, why, and a concrete suggested fix; findings
  grounded in the PR diff plus the repo's own standards (`docs/CODING_CONVENTIONS.md`,
  `language-specific/<lang>/SKILL.md`, `AGENTS.md`); no cosmetic-only nitpicks; no
  "security" finding without evidence; (c) comment mechanics — post findings as a PR review
  comment via `gh`, and end the comment with a machine-readable marker line
  `Reviewed-SHA: <head sha>` (consumed by T2's early-exit step).
- `opencode.json` gains a `provider` block named `opencode-go` with base URL
  `https://opencode.ai/zen/go/v1`, `env: ["OPENCODE_API_KEY"]`, and model `kimi-k3`. Nothing is
  added to the `agent` block (would trip `scripts/check-model-env.sh`).

Satisfies: AC-002 (scope lock in config), AC-003 (model/endpoint/auth), informal item 2
(scope lock), item 6 (review discipline), item 7 (security boundary).

Acceptance criteria (checkable by reading code):

- [AC-002] `agents/pr-review.md` exists; `mode: subagent`; the prompt's first directive states the agent reviews the PR diff and posts findings with suggested fixes only.
- [AC-002] The frontmatter `permission` block denies `edit` for all paths, and no allowed `bash` pattern matches `git push`, `git commit`, `gh pr merge`, `gh pr edit`, or any file-writing command.
- [AC-002] The prompt contains literal forbidden-operation strings: `describe`, `improve`, `auto-apply`, `title`/`summary` rewriting, `auto-merge`, `push`.
- [AC-003] `model:` in `agents/pr-review.md` frontmatter is exactly `opencode-go/kimi-k3` (literal, not an env reference).
- [AC-003] `opencode.json` `provider.opencode-go` defines base URL exactly `https://opencode.ai/zen/go/v1`, `env: ["OPENCODE_API_KEY"]`, and model `kimi-k3`; no other model id appears in the agent file or provider block.
- [AC-003] `bash scripts/check-model-env.sh` still exits 0 after the `opencode.json` change.
- [AC-002/6] The prompt requires each finding to include `file:line`, what is wrong, why, and a suggested fix; requires grounding in the diff and the repo standards; forbids cosmetic-only nitpicks; forbids security findings without evidence.
- [informal 8] The prompt requires the review comment to end with `Reviewed-SHA: <head sha>`.
- [informal 7] No secret value appears in `agents/pr-review.md` or `opencode.json` — only the name `OPENCODE_API_KEY`.
- [out-of-scope] The change set adds `agents/pr-review.md` and does not modify any `agents/spec-*.md`.

## T2 — Shared reusable workflow `.github/workflows/shared/pr-review.yml`

Create the reusable workflow that child repos (and this repo, via T3) call to run the review.

What the task must do:

- `on: workflow_call` reusable; declares `inputs` (`pr-number`, `head-sha`) and the
  `OPENCODE_API_KEY` secret **without** `required: true` (a caller without the key must be
  able to call it).
- `permissions:` exactly `contents: read` + `pull-requests: write` (comment-only; no
  `contents: write`, no merge/push step anywhere).
- One job, guarded so an empty key skips the whole job cleanly.
- Steps, in order: (1) `actions/checkout` of the caller repo with `submodules: true` and
  `persist-credentials: false`; (2) install the pinned opencode binary via
  `scripts/install-opencode.sh`; (3) make the pr-review agent discoverable to opencode by
  symlinking it into `.opencode/agents/`, resolving the agent from `agents/pr-review.md`
  (standards repo itself) or `.standards/agents/pr-review.md` (child repos); (4) early-exit
  step: read the PR's existing review comments, extract the `Reviewed-SHA:` marker; if the
  marker equals `head-sha` **and** `gh pr checks` reports all pass, exit 0 before invoking
  the model; (5) run step: `opencode run --print-logs` (no `--auto`), exporting
  `OPENCODE_API_KEY` from the secret, instructing the pr-review agent, passing `pr-number`
  and `head-sha`.

Satisfies: AC-001 (shared workflow, comment-only), AC-005 (skip-cleanly-without-key
mechanics), informal item 1 (trigger plumbing), item 8 (debounce + early exit + bounded cost
mechanics).

Acceptance criteria (checkable by reading code):

- [AC-001] `.github/workflows/shared/pr-review.yml` exists and triggers on `workflow_call`.
- [AC-001] The `permissions` block grants exactly `contents: read` and `pull-requests: write`; no step in the file runs `git push`, merges, or modifies repo content.
- [AC-005] The secret is declared without `required: true`; the review job is guarded by `if: ${{ secrets.OPENCODE_API_KEY != '' }}`, so an absent key yields a skipped job, never a failure.
- [AC-005] The file contains no literal key value — only the secret name.
- [AC-001] The run step invokes the pinned binary from `scripts/install-opencode.sh`, runs headless with `--print-logs`, and does not pass an auto-approve flag.
- [AC-001] The run step exports `OPENCODE_API_KEY` from the secret and passes `pr-number` and `head-sha` into the review prompt.
- [informal 5] The agent-discoverability step handles both `agents/pr-review.md` (this repo) and `.standards/agents/pr-review.md` (child), symlinking into `.opencode/agents/`.
- [informal 8] An early-exit step exists that skips the model run when the `Reviewed-SHA:` marker from a prior comment equals the current `head-sha` **and** all CI checks for the head pass; the run proceeds when the head changed or a check is failing.

## T3 — This repo's own trigger workflow `.github/workflows/pr-review.yml` (self-hosting proof)

Create the top-level workflow that makes the agent run on this repo's own PRs.

What the task must do:

- `on: pull_request` with types `opened`, `ready_for_review`, `synchronize`, `reopened`.
- A `concurrency` group keyed on the PR number with `cancel-in-progress: true` — only the
  latest head gets a live review (superseded runs cancel).
- One job calling the shared workflow from T2, guarded by
  `if: ${{ secrets.OPENCODE_API_KEY != '' }}`, passing `pr-number` and `head-sha` from
  `github.event.pull_request` and `OPENCODE_API_KEY` from the repo's secrets.

Satisfies: AC-001 (trigger), AC-005 (self-hosting proof; no-key run skips cleanly and never
fails the PR's required checks), informal item 1 (trigger), item 8 (latest-head debounce).

Acceptance criteria (checkable by reading code):

- [AC-001] `.github/workflows/pr-review.yml` exists; `on: pull_request` lists exactly the four types `opened`, `ready_for_review`, `synchronize`, `reopened`.
- [informal 8] A `concurrency` block exists keyed on `github.event.pull_request.number` with `cancel-in-progress: true`.
- [AC-005] The job is guarded by `if: ${{ secrets.OPENCODE_API_KEY != '' }}` — with no key configured the job is skipped (check state `skipped`, never `failure`), so the PR's required checks are unaffected.
- [AC-005] The job passes `OPENCODE_API_KEY: ${{ secrets.OPENCODE_API_KEY }}` and the PR number/head SHA to the shared workflow.
- [AC-005] No literal key value appears in the file; the key is referenced only via the `secrets` context.

## T4 — `scripts/init-ci.sh` gains `--with-pr-review`

Extend the CI generator so child repos opt in with one command, mirroring `--with-release`
(spec 022) line for line in structure.

What the task must do:

- New flag var `WITH_PR_REVIEW_FLAG`, parsed from `--with-pr-review` in the existing `case`
  (unknown-flag error behavior unchanged); usage line gains the flag.
- Secret prompt: `OPENCODE_API_KEY` is prompted in `_prompt_secrets` **only** when the flag
  is set (same gating as `GH_TOKEN` under `--with-release`).
- GitHub generation (`generate_github_ci`): a `_gh_pr_review_job` appends a `pr-review` job
  to the generated `ci.yml` that calls
  `RexiAI/my-engineering-standards/.github/workflows/shared/pr-review.yml@main` with
  `secrets: OPENCODE_API_KEY: ${{ secrets.OPENCODE_API_KEY }}`. The job runs on
  `pull_request` events of the child repo (no default-branch gate — reviews are per-PR).
- GitLab: GitHub-only feature — on `--platform gitlab` (or the gitlab half of `both`), print
  a warning and emit nothing; exit 0.
- Summary (`print_summary` / `_print_gh_secrets` / a `_print_pr_review_note`): when the flag
  is set, list `OPENCODE_API_KEY` under GitHub next steps with a pointer to
  `docs/CI_CD.md`'s new PR review section.
- Regression guard mirroring AC-022-03-03: without the flag, generated output is unchanged —
  no `pr-review` job, no `OPENCODE_API_KEY` line.

Satisfies: AC-004 (opt-in flag wiring the shared workflow + secret, mirroring `--with-release`),
informal item 5 (child-repo opt-in).

Acceptance criteria (checkable by reading code and running the script):

- [AC-004] `--with-pr-review` is accepted (run exits 0, no unknown-flag error) and appears in the usage line.
- [AC-004] With `--platform github` (or `both`) + the flag, the generated `.github/workflows/ci.yml` contains a `pr-review` job calling `.../shared/pr-review.yml@main` with `OPENCODE_API_KEY: ${{ secrets.OPENCODE_API_KEY }}`.
- [AC-004] Without the flag, the generated `ci.yml` contains no `pr-review` job and no `OPENCODE_API_KEY` line (default output byte-compatible with today).
- [AC-004] In interactive mode with the flag set, `OPENCODE_API_KEY` is prompted; without the flag it is never prompted.
- [AC-004] The summary's GitHub next steps list `OPENCODE_API_KEY` when the flag is set.
- [AC-004] With `--platform gitlab` + the flag: a warning is printed, nothing PR-review-related is emitted into `.gitlab-ci.yml`, and the run exits 0.

## T5 — Documentation: `docs/CI_CD.md` PR review section + `docs/SPEC_PIPELINE.md` cross-reference

Document the agent per AC-006, plus the two places the informal spec names.

What the task must do:

- New section in `docs/CI_CD.md` (e.g. `## PR Review Agent`) documenting: the scope lock
  (review + suggest fixes only; the disabled operations list), the pinned model
  `opencode-go/kimi-k3`, the endpoint `https://opencode.ai/zen/go/v1`, secret handling
  (`OPENCODE_API_KEY` from a GitHub secret, never committed — consistent with
  `docs/SECURITY.md §Secrets Management`), child-repo opt-in via
  `./.standards/scripts/init-ci.sh --with-pr-review` (additive, no-op boundary for children
  that never opt in, same framing as `§Release Process`), and cost/bounds (one review per
  relevant PR event, debounced to the latest head, early exit when the head is already
  reviewed and CI is green, no re-review of an unchanged head).
- Add the `OPENCODE_API_KEY` row to the `Required Secrets` table in `docs/CI_CD.md` and the
  shared workflow to the architecture tree in `docs/CI_CD.md §Architecture`.
- Add a short "Using OpenCode Zen" section to `docs/SPEC_PIPELINE.md` (model + endpoint +
  auth + pointer to the CI_CD.md section) per open question 1.

Satisfies: AC-006, informal item 8 (cost guidance documented).

Acceptance criteria (checkable by reading docs):

- [AC-006] `docs/CI_CD.md` contains a PR review agent section that mentions: the scope lock with the disabled operations, `opencode-go/kimi-k3`, `https://opencode.ai/zen/go/v1`, `OPENCODE_API_KEY` sourced from a GitHub secret (never committed), `init-ci.sh --with-pr-review` child-repo opt-in, and the cost/bounds rules (latest-head debounce, early exit when reviewed-and-green).
- [AC-006] The `Required Secrets` table lists `OPENCODE_API_KEY`; the architecture tree lists `shared/pr-review.yml`.
- [AC-006] `docs/SPEC_PIPELINE.md` contains a "Using OpenCode Zen" section cross-referencing the CI_CD.md PR review section.
- [AC-006] No doc contains a literal key value — only the name `OPENCODE_API_KEY`.

## Acceptance scenarios

## AC-024-01-01 — Agent file exists with review-only scope
## AC-024-01-02 — Model pinned to opencode-go/kimi-k3 in the agent config
## AC-024-01-03 — Zen provider wired to endpoint and auth
## AC-024-01-04 — No other model id in the reviewer's config
## AC-024-01-05 — Write operations disabled in the permission config
## AC-024-01-06 — Disabled operations named in the prompt
## AC-024-01-07 — Finding format is file:line + what + why + fix
## AC-024-01-08 — No cosmetic nitpicks, no un-evidenced security findings
## AC-024-01-09 — Findings grounded in the diff and the repo's standards
## AC-024-01-10 — Reviewed-SHA marker contract
## AC-024-01-11 — Model-env gate stays green
## AC-024-01-12 — Spec-pipeline agents untouched
## AC-024-02-01 — Shared workflow exists as a reusable
## AC-024-02-02 — Comment-only permissions
## AC-024-02-03 — Secret optional; empty key skips the job cleanly
## AC-024-02-04 — No literal key in the workflow
## AC-024-02-05 — Review runs against the caller repo at the PR head
## AC-024-02-06 — Pinned opencode binary
## AC-024-02-07 — Agent discoverable for both self-hosting and child repos
## AC-024-02-08 — No auto-approve in the run command
## AC-024-02-09 — Early exit when head already reviewed and CI green
## AC-024-02-10 — Review proceeds when the head changed
## AC-024-02-11 — Review proceeds when CI is failing on an untouched head
## AC-024-03-01 — Trigger on pull_request with the four types
## AC-024-03-02 — Per-PR concurrency with cancel-in-progress
## AC-024-03-03 — Calls the shared workflow with PR context
## AC-024-03-04 — Key supplied via GitHub secret
## AC-024-03-05 — No key: job skipped, never a required-check failure
## AC-024-03-06 — No literal key in the trigger workflow
## AC-024-03-07 — Self-hosting wiring is identical to child wiring
## AC-024-04-01 — Flag accepted and documented in usage
## AC-024-04-02 — GitHub generation emits the pr-review job
## AC-024-04-03 — Default output unchanged without the flag
## AC-024-04-04 — Secret prompted only when opted in
## AC-024-04-05 — Secret never prompted without the flag
## AC-024-04-06 — Summary lists the required secret for GitHub
## AC-024-04-07 — GitLab-only: warning, no emission, exit 0
## AC-024-04-08 — Both platforms: GitHub emits, GitLab warns
## AC-024-05-01 — CI_CD.md documents the PR review agent
## AC-024-05-02 — Required Secrets table gains the new secret
## AC-024-05-03 — Architecture tree lists the shared workflow
## AC-024-05-04 — SPEC_PIPELINE.md cross-references the section
## AC-024-05-05 — No literal key value in the docs

## Verification

# 024-pr-review-agent — Verification report

- Branch: `spec/024-pr-review-agent` (HEAD `f3e0375`, base `origin/main` `f6824da`)
- Verifier: spec-verifier (stage 4), attempt 1, phase 1
- Scope: verify against `10-tasks.md` + `20-acceptance/` only. `00-informal.md` not read (information barrier).
- Change set (12 files): `.github/workflows/pr-review.yml`, `.github/workflows/self-ci.yml`,
  `.github/workflows/shared/pr-review.yml`, `agents/pr-review.md`, `docs/CI_CD.md`,
  `docs/SPEC_PIPELINE.md`, `opencode.json`, `scripts/check-model-env.sh`,
  `scripts/check-pr-review.selftest.sh`, `scripts/check-pr-review.sh`, `scripts/init-ci.sh`,
  `scripts/model-env.selftest.sh` (1294 insertions, 15 deletions).

---

## Check 1 — Scenario traceability

## Evidence: scenario traceability

command: bash scripts/check-scenario-traceability.sh --json
exit: 1
at: 2026-08-19T15:08:06Z

{
  "checks": [1, 2],
  "passes": ["AC-024-01 — traced to a test", "AC-024-02 — traced to a test", "AC-024-03 — traced to a test", "AC-024-04 — traced to a test", "AC-024-05 — traced to a test"],
  "fails": [ <142 items — see breakdown below> ]
}

Breakdown of the 142 fails (reprised from the JSON transcript, verbatim text):

- Check 1 fails (scenario defined, no test references it) — 5 items, ALL from the in-flight spec 023 folder, none from 024:
  - "AC-023-01 — scenario defined in specs/*/20-acceptance/ but no test references it.  Add a test named after this ID, or confirm with 10-tasks.md that it's obsolete  and remove the scenario instead of leaving it untraced."
  - "AC-023-02 …" / "AC-023-03 …" / "AC-023-04 …" / "AC-023-05 …" (identical wording)
- Check 2 fails (referenced in a test but no matching scenario heading) — 137 items, all IDs AC-001-01 … AC-022-04 plus selftest fixtures AC-888-88, AC-998-01, AC-999-01/02/03/99. Zero AC-024 fails.

### Scoped isolation to spec 024's surface

- All 43 AC-024 scenario headings (12+11+7+8+5 per file; the script groups them into the 5 section IDs AC-024-01..05) are traced: every one of the 43 individual IDs is cited in `scripts/check-pr-review.sh` (213 citations, 43 unique — verified by `grep -oE 'AC-024-0[1-5]-[0-9]{2}' scripts/check-pr-review.sh | sort -u | wc -l` = 43), which is wired into self-ci's Validate job.
- Every AC-024 reference in the source tree resolves: zero AC-024 entries appear in the check-2 fail list.
- Change-set analysis (`git diff origin/main..HEAD` added lines only): the change adds references to AC-024-01..05 (all resolve) plus more references to the already-dangling AC-020-01 in `scripts/model-env.selftest.sh` (72 AC-020 refs already on `origin/main` — same failing ID, fail set unchanged). No NEW dangling reference is introduced by this change.

### Baseline verification

- The check-2 fail IDs originate from `docs/changes/*.md` archived-spec one-pagers (1425 AC refs; archived specs' scenario headings no longer exist under `specs/`), selftest fixtures (`scripts/*.selftest.sh` dummy IDs AC-888-88/998/999), and pre-existing refs already on `origin/main` (docs/SPEC_PIPELINE.md 6× AC-002, scripts/init-ci.sh 13× AC-022, scripts/model-env.selftest.sh 72× AC-020).
- The check-1 fail IDs originate from `specs/023-pr-review-agent/20-acceptance/` (in-flight spec, no test carrier committed yet).
- The change set touches none of these files' dangling sources.

VERDICT: PASS for spec 024's surface. Full-repo exit 1 is pre-existing baseline noise (in-flight AC-023 + archived-spec dangling refs), not caused by this change. Human note: full-repo traceability stays red until spec 023 ships its test carrier and `docs/changes/*.md` refs are reconciled — flag to Architect.

---

## Check 2 — Full test suite (self-ci gates relevant to this change)

## Evidence: full test suite

command: bash scripts/check-pr-review.sh
exit: 0
at: 2026-08-19T15:08:18Z

Checking PR review agent deliverables in: /tmp/mesh-review
PASS AC-024-01-01: 'mode: subagent' present in agents/pr-review.md
PASS AC-024-01-01: 'review the PR diff' present in agents/pr-review.md first directive
PASS AC-024-01-01: 'suggested fixes' present in agents/pr-review.md first directive
PASS AC-024-01-02: frontmatter model: is exactly opencode-go/kimi-k3 (literal)
PASS AC-024-01-02: model value is not an {env:...} reference
PASS AC-024-01-03: '"opencode-go"' present in opencode.json provider block
PASS AC-024-01-03: 'https://opencode.ai/zen/go/v1' present in opencode.json provider block
PASS AC-024-01-03: '"OPENCODE_API_KEY"' present in opencode.json provider block
PASS AC-024-01-03: 'kimi-k3' present in opencode.json provider block
PASS AC-024-01-04: only model id in agents/pr-review.md is opencode-go/kimi-k3
PASS AC-024-01-04: opencode.json carries no provider-qualified model pin
PASS AC-024-01-05: 'edit:' present in agents/pr-review.md frontmatter
PASS AC-024-01-05: '"*": deny' present in agents/pr-review.md frontmatter
PASS AC-024-01-05: no allowed bash pattern matches git push/commit/add/checkout/reset/worktree, gh pr merge/edit, or file editors
PASS AC-024-01-06: forbidden operations named in the prompt
PASS AC-024-01-07: finding format requires file:line, what, why, fix
PASS AC-024-01-08: review discipline forbids nitpicks and un-evidenced security findings
PASS AC-024-01-09: findings grounded in the diff and the repo standards
PASS AC-024-01-10: review comment ends with the Reviewed-SHA marker
PASS AC-024-01-11: scripts/check-model-env.sh exits 0 with the provider block present
PASS AC-024-01-12: exactly the 8 spec-pipeline agents exist under agents/, none added
PASS AC-024-01-12: no agents/spec-*.md file is modified in the change set
PASS AC-024-02-01: shared workflow is a workflow_call reusable
PASS AC-024-02-02: permissions grant exactly contents: read + pull-requests: write
PASS AC-024-02-02: no broader permission, no content-modifying step
PASS AC-024-02-03: 'OPENCODE_API_KEY:' present in workflow_call secrets block
PASS AC-024-02-03: OPENCODE_API_KEY is declared without required: true
PASS AC-024-02-03: review job guarded by the empty-key check
PASS AC-024-02-04: no key-shaped value in the workflow
PASS AC-024-02-04: OPENCODE_API_KEY appears in the shared workflow only as the secret name
PASS AC-024-02-05: checkout checks out the caller with submodules and no persisted credentials
PASS AC-024-02-05: run step passes pr-number and head-sha into the invocation
PASS AC-024-02-06: pinned binary installed, headless --print-logs run
PASS AC-024-02-07: agent symlinked into .opencode/agents from agents/ or .standards/agents/
PASS AC-024-02-08: run command passes no auto-approve or skip-permissions flag
PASS AC-024-02-09: early-exit extracts the Reviewed-SHA marker from prior comments
PASS AC-024-02-09: early-exit compares the marker to the current head-sha
PASS AC-024-02-09: early-exit requires gh pr checks all green
PASS AC-024-02-09: model-run step is conditional on the early-exit output
PASS AC-024-02-10: skip requires marker == head-sha; a changed head proceeds
PASS AC-024-02-11: a non-green check keeps skip=false, so the run proceeds
PASS AC-024-03-01: trigger is pull_request
PASS AC-024-03-01: types list has exactly 4 entries
PASS AC-024-03-01: no extra pull_request types
PASS AC-024-03-02: concurrency keyed on the PR number with cancel-in-progress
PASS AC-024-03-03: job calls the shared pr-review workflow@main
PASS AC-024-03-03: pr-number and head-sha passed from the PR event
PASS AC-024-03-04: OPENCODE_API_KEY mapped from secrets
PASS AC-024-03-05: job guarded by the empty-key check
PASS AC-024-03-06: no key-shaped value in the trigger workflow
PASS AC-024-03-06: OPENCODE_API_KEY appears in the trigger workflow only as the secret name
PASS AC-024-03-07: trigger workflow and init-ci.sh emit the same shared pr-review workflow@main
PASS AC-024-04-01: usage line lists --with-pr-review
PASS AC-024-04-01: --with-pr-review parsed into WITH_PR_REVIEW_FLAG
PASS AC-024-04-02: generated ci.yml carries the pr-review job
PASS AC-024-04-03: default ci.yml has no pr-review job and no OPENCODE_API_KEY line
PASS AC-024-04-07: --platform gitlab with the flag exits 0
PASS AC-024-04-07: GitLab run prints the GitHub-only warning
PASS AC-024-04-07: nothing PR-review-related emitted into .gitlab-ci.yml
PASS AC-024-04-08: --platform both emits the GitHub pr-review job and warns on GitLab
PASS AC-024-04-04: OPENCODE_API_KEY prompt is gated on WITH_PR_REVIEW_FLAG
PASS AC-024-04-05: exactly one OPENCODE_API_KEY prompt exists, and it is flag-gated (never prompted without the flag)
PASS AC-024-04-06: summary's GitHub next steps list OPENCODE_API_KEY
PASS AC-024-05-01: 'review + suggest fixes only' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'describe' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'improve' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'auto-apply' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'auto-merge' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'push' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'opencode-go/kimi-k3' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'https://opencode.ai/zen/go/v1' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'OPENCODE_API_KEY' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'never committed' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'init-ci.sh --with-pr-review' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'never opts in' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'latest head' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'Early exit' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'Reviewed-SHA' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-01: 'One review per relevant PR event' present in docs/CI_CD.md PR Review Agent section
PASS AC-024-05-02: Required Secrets table lists OPENCODE_API_KEY as opt-in
PASS AC-024-05-03: 'pr-review.yml' present in docs/CI_CD.md Architecture tree
PASS AC-024-05-04: 'https://opencode.ai/zen/go/v1' present in docs/SPEC_PIPELINE.md Using OpenCode Zen section
PASS AC-024-05-04: 'OPENCODE_API_KEY' present in docs/SPEC_PIPELINE.md Using OpenCode Zen section
PASS AC-024-05-04: 'opencode-go/kimi-k3' present in docs/SPEC_PIPELINE.md Using OpenCode Zen section
PASS AC-024-05-04: 'CI_CD.md §PR Review Agent' present in docs/SPEC_PIPELINE.md Using OpenCode Zen section
PASS AC-024-05-05: no key-shaped value in docs/CI_CD.md
PASS AC-024-05-05: no key-shaped value in docs/SPEC_PIPELINE.md
PASS self-citation: every AC-024-NN-NN scenario ID is cited by this script
PASS self-citation: every AC-024 reference inside the script resolves to a scenario ID
PASS self-ci: .github/workflows/self-ci.yml runs check-pr-review.sh in the Validate job
✔ PR review agent check: every check passed.
(86 checks, 0 failures)

Note: the AC-024-04-02/03/07/08 PASS lines come from real executions — the gate runs init-ci.sh in a mktemp scratch child repo (`.standards` symlinked) and inspects the generated ci.yml/.gitlab-ci.yml.

## Evidence: full test suite

command: bash scripts/check-pr-review.selftest.sh
exit: 0
at: 2026-08-19T15:08:19Z

== AC-024-04-04 / AC-024-04-05 secret prompt gating (interactive) ==
PASS AC-024-04-04: OPENCODE_API_KEY is prompted when --with-pr-review is set (2 occurrences)
PASS AC-024-04-05: OPENCODE_API_KEY is never prompted without --with-pr-review

selftest: 2 passed, 0 failed
✔ check-pr-review.selftest: all cases pass.
(Real behavioral proof: init-ci.sh run under script(1) pseudo-TTY with/without the flag; prompt occurrences counted in the transcript.)

## Evidence: full test suite

command: bash scripts/check-model-env.sh
exit: 0
at: 2026-08-19T15:08:20Z

PASS check-model-env: all model values are {env:SPEC_*_MODEL} references, no tracked real env file, example wired.

## Evidence: full test suite

command: bash scripts/check-orchestration.sh
exit: 0
at: 2026-08-19T15:08:34Z

Checking agent references (commands/, agents/)...
Checking skill references (agents/)...
Checking scripts/ references (agents/, commands/, AGENTS.md)...
Checking docs/ and language-specific/ references (agents/)...

All orchestration references valid.

## Evidence: full test suite

command: bash scripts/model-env.selftest.sh
exit: 0
at: 2026-08-19T15:08:37Z

PASS AC-020-05-05 example var with no reference: exit 1, output names SPEC_UNUSED_MODEL
PASS AC-020-06-01 load-model-env.sh exists, bash, set -euo pipefail
PASS AC-020-06-01 check-model-env.sh exists, bash, set -euo pipefail
PASS AC-020-06-01 model-env.runtime-check.sh exists, bash, set -euo pipefail
PASS AC-020-06-01 model-env.runtime-check.sh builds fixtures in mktemp -d with trap cleanup
PASS AC-020-06-05 self-ci validate job downloads the pinned opencode tarball and runs all three scripts
PASS AC-020-06-05 no continue-on-error on the model-env step — a regression must fail the job
PASS AC-020-07-01 SPEC_PIPELINE.md documents profile wiring, copy→fill→restart, no commit, precedence, enforcement
PASS AC-020-07-02 AGENTS.md model table points at config/model.local.env via load-model-env.sh, restart not commit
PASS AC-020-07-03 SPEC_PIPELINE.md cites check-model-env.sh and the self-ci pinned-binary runtime check

selftest: 31 passed, 0 failed
✔ model-env.selftest: all cases pass.
(Including the updated AC-020-01-01 carve-out asserting the pr-review agent carries the literal `model: opencode-go/kimi-k3` pin.)

## Evidence: full test suite

command: make lint
exit: 0
at: 2026-08-19T15:07:00Z

Validating JSON files... / Validating YAML files (.github + ci) — all [OK], including .github/workflows/pr-review.yml and .github/workflows/shared/pr-review.yml. "Done."

## Evidence: full test suite

command: make validate-all
exit: 0
at: 2026-08-19T15:07:15Z

All 35 files present. / Checking cross-references... All cross-references valid. / All SKILL.md files valid (1 warning(s)) — WARN is the pre-existing skills/hallmark line-count (562 lines > 500 limit), unrelated to this change. "All validations passed."

## Evidence: full test suite

command: bash -n on changed scripts + python3 YAML parse on changed workflows
exit: 0
at: 2026-08-19T15:06:55Z

[OK] scripts/check-pr-review.sh
[OK] scripts/check-pr-review.selftest.sh
[OK] scripts/check-model-env.sh
[OK] scripts/model-env.selftest.sh
[OK] scripts/init-ci.sh
[OK] .github/workflows/pr-review.yml
[OK] .github/workflows/shared/pr-review.yml
[OK] .github/workflows/self-ci.yml

## Evidence: full test suite

command: bash scripts/check-no-hardcoded-secrets.sh
exit: 0
at: 2026-08-19T15:08:22Z

PASS check-no-hardcoded-secrets: no hardcoded credential values in agents/, commands/, scripts/, docs/.

Self-ci wiring confirmed by reading `.github/workflows/self-ci.yml`: the Validate job now runs `./scripts/check-pr-review.sh` + `./scripts/check-pr-review.selftest.sh` in a dedicated step (no continue-on-error), plus the pre-existing model-env step (check-model-env.sh, model-env.selftest.sh, model-env.runtime-check.sh) and check-orchestration.sh — all exit 0 above. The runtime-check step needs a network download of the pinned binary (v1.18.18) — not re-run locally; its gate script (model-env.runtime-check.sh) is exercised by model-env.selftest.sh assertions and its wiring is unchanged by this spec.

VERDICT: PASS.

---

## Check 3 — Complexity gate

## Evidence: complexity gate

command: manual review of changed-surface complexity (bash/YAML/markdown/JSON — no Java/Go/JS files in the change set) + bash scripts/check-code-principles.sh -BaseRef origin/main (complexity gate is part of the design-principles gate, see Check 4)
exit: 0
at: 2026-08-19T15:08:36Z

Changed surface contains no Java/Go/JS source, so no language linter measures cyclomatic complexity here; the design-principles gate's Complexity/KISS checks ran scoped (0 FAIL). Manual review of the three flagged spots:

1. Early-exit inline script — `.github/workflows/shared/pr-review.yml` lines 84-101: single while-read loop + one `case` (Reviewed-SHA extraction) + one `if` with `&&` (marker match AND `gh pr checks` all SUCCESS/SKIPPED). Control paths ≤ 4. No nested conditionals. CC ≤ 6. Claim confirmed.
2. `_gh_pr_review_job` — `scripts/init-ci.sh` lines 436-456: single early-return guard (`[ "$WITH_PR_REVIEW_FLAG" != "true" ] && return 0`) then one heredoc append. CC ≤ 2. Claim confirmed.
3. `scripts/check-pr-review.sh` — 8 functions: `fail`/`pass` (1), `verify_grep` (loop + if, CC 3), `verify_absent` (single if, 2), `frontmatter`/`body` (awk one-liners, 1), `str_contains` (single if, 2), `verify_secret_name_only` (pipeline + if, 3). Main body is sequential grep/verify calls. All CC ≤ 3. Claim confirmed.

Refactorer's claim ("every function ≤6 with no violations on the changed surface") holds under re-check.

VERDICT: PASS.

---

## Check 4 — Design-principles gate

## Evidence: design-principles gate

command: bash scripts/check-code-principles.sh -BaseRef origin/main
exit: 0
at: 2026-08-19T15:08:36Z

Checking design principles in: . (tier: mvp)
PASS Complexity/KISS (java): no violations found
--- DRY ---
--- YAGNI ---
PASS YAGNI (go): no premature abstractions detected
PASS YAGNI (node): no premature abstractions detected
--- SOLID ---
PASS SOLID-SRP (java): no oversized files
PASS SOLID-SRP (go): no oversized files
PASS SOLID-SRP (node): no oversized files
PASS SOLID-OCP (java): no large type-dispatch chains
PASS SOLID-OCP (go): no large type-dispatch chains
PASS SOLID-OCP (node): no large type-dispatch chains
PASS SOLID-LSP (java): no heavy instanceof dispatch
PASS SOLID-LSP (node): no heavy instanceof dispatch
PASS SOLID-ISP (java): no fat interfaces
PASS SOLID-ISP (node): no fat interfaces
PASS SOLID-DIP (java): no domain→infrastructure imports
PASS SOLID-DIP (go): no domain→infrastructure imports
PASS SOLID-DIP (node): no domain→infrastructure imports
--- Property tests ---
Property tests: skipped (project tier is mvp — production+ required)
---------------------------------------------
✔ Design-principles check: 0 FAIL(s), 0 WARN(s).

Scoped verdict: 0 FAIL / 0 WARN on the change set — confirms the Refactorer's claim.

## Evidence: design-principles gate (whole-tree baseline, for comparison)

command: bash scripts/check-code-principles.sh
exit: 1
at: 2026-08-19T15:08:50Z

FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:158:checkCompensationPairs:CC=14
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:158:checkCompensationPairs:KISS_LINES=59
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:203:checkOutboxCoLocation:CC=10
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:203:checkOutboxCoLocation:KISS_LINES=42
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:243:checkSagaHandlerContext:CC=10
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:243:checkSagaHandlerContext:KISS_LINES=38
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:304:resolveDirs:CC=8
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:304:resolveDirs:KISS_LINES=31
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:69:getSagaStepOptions:CC=7
+ 12 further WARN lines (duplication / empty-method-body) in ci/templates/archunit/*.java, go-saga-lint.go, saga-compensation.js
✘ Design-principles check: 5 FAIL(s), 17 WARN(s).

Baseline verification: the 5 FAILs and all 17 WARNs are confined to `ci/templates/` (spec 022 saga/outbox gate surface). The change set touches 0 files under `ci/templates/` (`git diff origin/main..HEAD --name-only` = 0 matches; those files' last change is commit 9db5ee9, predating this branch). The failure is genuinely pre-existing and not caused by this change.

VERDICT: PASS for the change set; pre-existing whole-tree baseline failure confirmed (flag to Architect as spec 022 surface debt).

---

## Check 5 — Scenario-to-behavior spot check

## Evidence: scenario-to-behavior spot check

command: manual code inspection of two acceptance scenarios against the actual gate/workflow code
exit: 0
at: 2026-08-19T15:09:00Z

### AC-024-01-02 — Model pinned to opencode-go/kimi-k3 (from AC-024-01)

Scenario G/W/T: `model` key in agents/pr-review.md frontmatter is exactly `opencode-go/kimi-k3`, literal, not `{env:...}`.

Actual code read:
- `agents/pr-review.md` line 4: `model: opencode-go/kimi-k3` — literal. Line 5-17 permission block: `edit: "*": deny`; bash allow-list only `git diff/show/log/status` + `gh pr view/diff/checks/comment`; everything else `ask`. No pattern matches `git push`, `git commit`, `gh pr merge/edit` or file-writing commands.
- `opencode.json` provider block: `"opencode-go": { "env": ["OPENCODE_API_KEY"], "options": { "baseURL": "https://opencode.ai/zen/go/v1" }, "models": { "kimi-k3": {} } }`.
- Gate assertions (check-pr-review.sh): `grep -q '^model: opencode-go/kimi-k3$'` + `verify_absent 'model:[[:space:]]*\{env:'` + provider-block string checks + model-id uniqueness check (only `opencode-go/kimi-k3` in the agent file, no provider-qualified pin in opencode.json) + a real `scripts/check-model-env.sh` run (AC-024-01-11). The gate asserts the scenario's actual claims, not just the ID. Confirmed by my own re-read of the files + the gate's 5 PASS lines for AC-024-01-02/03/04/11.

### AC-024-02-09/10/11 — Early exit when head already reviewed and CI green (from AC-024-02)

Scenario G/W/T: marker `Reviewed-SHA: <head-sha>` from a prior comment + all CI checks pass → skip model run; head changed → run; checks failing on untouched head → run.

Actual code read — `.github/workflows/shared/pr-review.yml` lines 82-104:
- Early-exit step (id `early-exit`, lines 84-101): reads all comment bodies via `gh pr view "${PR_NUMBER}" --json comments --jq '.comments[].body'`; a `case` extracts the `Reviewed-SHA: ` value; `skip=false` initially; only if `reviewed_sha == HEAD_SHA` does it run `gh pr checks ... --jq 'all(.state == "SUCCESS" or .state == "SKIPPED")'`; only then `skip=true` and it prints the skip message.
- Run step (lines 103-104): `if: steps.early-exit.outputs.skip != 'true'` — the model runs unless skip is true. This is exactly the three scenarios: marker mismatch → run (AC-024-02-10); marker match + all green → skip (AC-024-02-09); marker match + any non-green → `gh pr checks` jq returns false → skip stays false → run (AC-024-02-11).
- The gate asserts the structural pieces (marker extraction, head comparison, checks-all-green, conditional run step) with 5 PASS lines for AC-024-02-09/10/11; I read the actual YAML and the logic matches the scenarios' Given/When/Then. Confirmed.

### AC-024-04-04/05 — Secret prompt gating (behavioral proof)

The selftest runs init-ci.sh under `script(1)` pseudo-TTY in a scratch child repo, with and without `--with-pr-review`, and counts `OPENCODE_API_KEY` prompt occurrences (2 with flag, 0 without). This is a real behavioral assertion of the interactive prompt gating, not a static grep. Confirmed by the selftest output above (2 passed) and my read of the selftest source.

VERDICT: PASS. The gate/workflow code asserts what the scenarios claim; no false-green pattern found.

---

## Finding: no unaccounted behavior

finding: no unaccounted behavior

All 12 changed files trace to T1-T5 / AC-024-01..05. Full diff skimmed (added lines): workflows (AC-024-02/03), agent config (AC-024-01), opencode.json provider block (AC-024-01-03), docs sections (AC-024-05), init-ci.sh flag/prompt/job/summary/gitlab-warning (AC-024-04), check-model-env.sh provider-block carve-out (required by T1's provider-block mandate; code-commented), model-env.selftest.sh AC-020-01-01 carve-out for the pr-review pin (required by AC-024-01-02; code-commented), self-ci gate wiring (spec's test carrier). Nothing untraceable. The two carve-outs modify pre-existing gate assertions rather than adding behavior — both necessary consequences of the spec's own requirements and both keep their gates green (check-model-env exit 0; model-env selftest 31 passed).

## Finding: review note (not a gate failure) — child-repo script path resolution

finding: review note

The shared workflow resolves `bash scripts/install-opencode.sh` (line 60) and `source scripts/load-model-env.sh` (line 113) from the caller's top level. This repo's self-hosting path works (top-level `scripts/` exists). Child repos, per `docs/CI_CD.md` structure and `scripts/bootstrap.sh`, have no top-level `scripts/` — only `.standards/scripts/` — so a child opting in via `--with-pr-review` would hit a missing-file failure at the install step (the agent-discoverability step at lines 66-69 handles both `agents/` and `.standards/agents/`, but the install/load steps do not). The spec itself (T2, AC-024-02-06) mandates the `scripts/install-opencode.sh` path verbatim, so the implementation matches the acceptance criteria as written. Flagging for human decision: either accept (children must vendor a top-level scripts/ or the workflow needs a `.standards/scripts/` fallback, which would be a spec-adjacent change) or amend the spec.

## Finding: human-changed values confirmed

finding: model pin / endpoint consistency (human changed these from the original spec draft)

- Model id: `opencode-go/kimi-k3` — 17 occurrences in the change set, all `kimi-k3`; no other provider-qualified id appears. Present in `agents/pr-review.md` frontmatter (literal), `opencode.json` provider block (`models: { "kimi-k3": {} }`), `docs/CI_CD.md §PR Review Agent`, `docs/SPEC_PIPELINE.md §Using OpenCode Zen` + `§Model configuration` carve-out.
- Endpoint: `https://opencode.ai/zen/go/v1` — 6 occurrences, the only base URL in the change set. Present in `opencode.json` provider block and both docs.
- Auth: `OPENCODE_API_KEY` env var — provider `env` array, workflow secret mapping, docs; no literal key value anywhere (check-no-hardcoded-secrets exit 0; per-file key-shape scans PASS).
- check-model-env.sh stays green with the provider block present (exit 0, re-run above).

---

## Overall verdict

**PASS** — every gate ran and produced no findings attributable to spec 024.

Per-gate summary:

| Check | Exit | Verdict |
|---|---|---|
| 1. Scenario traceability (spec 024 surface) | 1 (full repo) / scoped clean | PASS for spec 024 — pre-existing baseline noise (AC-023 in-flight + archived-spec dangling refs) |
| 2. Full test suite (self-ci gates) | 0 everywhere | PASS |
| 3. Complexity gate (changed surface) | 0 | PASS |
| 4. Design-principles gate (scoped -BaseRef) | 0 | PASS — pre-existing whole-tree baseline failure in ci/templates/ (spec 022) confirmed |
| 5. Scenario-to-behavior spot check | 0 | PASS |
| No unaccounted behavior | — | PASS (2 review notes above) |

Pre-existing baseline issues confirmed (NOT caused by this change):
1. Full-repo scenario-traceability exits 1: 5 untraced AC-023 scenarios (in-flight spec 023) + 137 dangling refs from archived specs (`docs/changes/*.md`) and selftest fixtures.
2. Whole-tree design-principles exits 1: 5 FAILs / 17 WARNs in `ci/templates/` (go-saga-lint.go, saga-compensation.js, archunit) — spec 022 surface, untouched by this change set.

Telemetry: `scripts/record-gate-run.sh` invoked — see runs.jsonl (record below, gate `traceability` recorded as pass-with-baseline-noise per the scoped isolation; no FAIL/BLOCK gates for spec 024).

Report written to `specs/024-pr-review-agent/25-verification.md`.

## Quality gates

# 024-pr-review-agent — Mutation Runner report (stage 5a)

- Branch: `spec/024-pr-review-agent` (HEAD `f3e0375`, base `origin/main` `f6824da`)
- Stage: spec-mutation-runner (stage 5a). `00-informal.md` not read (information barrier).
- Verifier verdict carried forward: **PASS** (`25-verification.md`, attempt 1, phase 1).

## Mutation testing: skipped — `mvp` tier (one-line skip note)

Mutation testing is a `production`-tier gate (`docs/CONFORMANCE_TIERS.md` §Tier assignments,
`docs/SPEC_PIPELINE.md` §Conformance tiers). This repo auto-detects `mvp` — no
`AGENTS_<PROJECT>.md` tier declaration exists — so the mutation-testing gate is **skipped**.
No mutation score is produced. No tests were written; no production code was touched.

### Why the gate does not apply (tier + tooling, doubly)

1. **Tier**: `mvp` → the Architect/Mutation-Runner gate row is `skip` at `mvp`.
2. **Tooling**: even at `production`, the mutation-tooling matrix
   (`docs/SPEC_PIPELINE.md` §Tooling by language) maps mutation testing to PiTest (Java),
   go-mutesting/gremlins (Go), and Stryker (JS/TS). The change set contains zero
   Java/Go/JS source — the implementation surface is bash gate scripts, GitHub Actions
   YAML workflows, markdown agent config, JSON `opencode.json`, and docs. No mutation
   tool in the matrix (or standard tooling at all) targets that surface. Nothing to
   mutate, no tool that could.

## Evidence: conformance tier determination

command: glob AGENTS_\*.md (project root) ; bash scripts/check-code-principles.sh -BaseRef origin/main
exit: 0
at: 2026-08-19T15:12:53Z

glob AGENTS_*.md matched only docs/AGENTS_AND_SKILLS.md — a standards document, not a
project tier declaration. Per CONFORMANCE_TIERS.md ("A project states its tier once, in
its own AGENTS_<PROJECT>.md"), no declaration = the mvp floor.

check-code-principles.sh -BaseRef origin/main output (representative excerpt):

---
Property tests: skipped (project tier is mvp — production+ required)
Property tests: skipped (project tier is mvp — production+ required)
Property tests: skipped (project tier is mvp — production+ required)

---------------------------------------------
✔ Design-principles check: 0 FAIL(s), 0 WARN(s).
---

(Head line of the same run: "Checking design principles in: . (tier: mvp)" — also recorded
verbatim in `25-verification.md` Check 4 evidence.)

## Evidence: mutation-testing applicability

command: git diff --name-only origin/main..HEAD ; docs/SPEC_PIPELINE.md §Tooling by language
exit: 0
at: 2026-08-19T15:12:43Z

Change set (12 files, verifier-confirmed): .github/workflows/pr-review.yml,
.github/workflows/self-ci.yml, .github/workflows/shared/pr-review.yml, agents/pr-review.md,
docs/CI_CD.md, docs/SPEC_PIPELINE.md, opencode.json, scripts/check-model-env.sh,
scripts/check-pr-review.selftest.sh, scripts/check-pr-review.sh, scripts/init-ci.sh,
scripts/model-env.selftest.sh. Extensions: yml, md, json, sh. Zero .java / .go / .js/.ts.
No PiTest / go-mutesting / gremlins / Stryker target exists for bash+YAML+markdown;
the pipeline's own tooling matrix lists none. Mutation testing inapplicable.

## Equivalent mutants

None. No mutation run was performed, so no equivalent mutants were observed or named.

## Complexity summary (carried from the Refactorer, re-confirmed by the Verifier, Check 3)

No Java/Go/JS source in the change set, so no language linter measures cyclomatic
complexity; the design-principles gate's Complexity/KISS checks ran scoped with 0 FAIL.
Manual re-check of the three flagged spots, every function ≤ 6:

| Surface | CC |
|---|---|
| `.github/workflows/shared/pr-review.yml` early-exit inline script (lines 84-101) — single while-read loop + one `case` + one `if` with `&&`; no nested conditionals | ≤ 4 |
| `_gh_pr_review_job` in `scripts/init-ci.sh` (lines 436-456) — single early-return guard + one heredoc append | ≤ 2 |
| `scripts/check-pr-review.sh` — 8 functions: `fail`/`pass` (1), `verify_grep` (3), `verify_absent` (2), `frontmatter`/`body` awk one-liners (1), `str_contains` (2), `verify_secret_name_only` (3); main body sequential | all ≤ 3 |

Claim "every function ≤6 with no violations on the changed surface" holds under re-check.

## Gate results (design-principles + complexity)

## Evidence: design-principles gate (scoped to the change set)

command: bash scripts/check-code-principles.sh -BaseRef origin/main
exit: 0
at: 2026-08-19T15:12:53Z

0 FAIL(s), 0 WARN(s). Whole-tree baseline failure (exit 1, 5 FAIL / 17 WARN confined to
ci/templates/, spec 022 surface) is pre-existing and untouched by this change set —
re-confirmed in `25-verification.md` Check 4.

## Final test status

Re-run of the full relevant suite on this tree, all green:

## Evidence: final test status — acceptance gate

command: bash scripts/check-pr-review.sh
exit: 0
at: 2026-08-19T15:12:43Z

✔ PR review agent check: every check passed. (86 checks, 0 failures) — all 43 AC-024
scenario IDs cited; all AC-024-01..05 assertions PASS.

## Evidence: final test status — acceptance gate selftest

command: bash scripts/check-pr-review.selftest.sh
exit: 0
at: 2026-08-19T15:12:43Z

selftest: 2 passed, 0 failed — AC-024-04-04/05 secret-prompt gating under pseudo-TTY.

## Evidence: final test status — model-env gates

command: bash scripts/check-model-env.sh ; bash scripts/model-env.selftest.sh
exit: 0
at: 2026-08-19T15:12:44Z

PASS check-model-env: all model values are {env:SPEC_*_MODEL} references, no tracked real
env file, example wired. selftest: 31 passed, 0 failed (incl. the AC-020-01-01 carve-out
for the pr-review agent's literal `opencode-go/kimi-k3` pin).

## Evidence: final test status — orchestration

command: bash scripts/check-orchestration.sh
exit: 0
at: 2026-08-19T15:12:44Z

All orchestration references valid.

## Evidence: final test status — lint

command: make lint
exit: 0
at: 2026-08-19T15:12:52Z

Validating JSON files... / Validating YAML files (.github + ci) — all [OK], including
.github/workflows/pr-review.yml and .github/workflows/shared/pr-review.yml. "Done."

## Remediation record

**none** — no BLOCK occurred during this run or any prior stage of this spec.

Carried forward from `25-verification.md` (Verifier, attempt 1, phase 1, no re-verification
attempts) and the orchestrator's loop telemetry (`runs.jsonl` run 2a33a8a8-...: phase1Retries
0, phase2Retries 0, gatesFailed []): the Verifier passed every gate on its first attempt;
the Mutation Runner ran no gates that could block. No phase-1 or phase-2 BLOCK entries exist
to carry; the pipeline consumed 0 of the 3 attempts in each budget.

## Finding: working tree dirty at stage start (not a BLOCK)

finding: working tree dirty

At stage-5a start the tree carried three uncommitted items, all pipeline-owned and all
already covered by the Verifier's PASS evidence (which ran on exactly this contents):
(1) `scripts/check-pr-review.sh` — the Refactorer's uncommitted DRY extraction of
`verify_secret_name_only` (AC-024-02-04 / AC-024-03-06 share one implementation); the
Verifier's 86-check run at 15:08:18Z executed this refactored code, exit 0, and my re-run
above confirms it again; (2) `runs.jsonl` — telemetry append by `scripts/record-gate-run.sh`,
documented in `25-verification.md`; (3) untracked `specs/` — the pipeline's own scratch
folder. Per the Stop-and-Ask matrix I did not stash or auto-commit; I reported the state
and proceeded with read-only gates. No foreign/unaccounted change present; nothing for the
PR Opener beyond the normal commit of this stage's work.

PR: https://github.com/RexiAI/my-engineering-standards/pull/42
Commit count: 10
