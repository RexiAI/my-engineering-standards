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

3. **Model: `opencode-zen/kimi-k3` only.** The PR review agent uses Kimi K3 via
   the OpenCode Zen endpoint (`https://opencode.ai/zen/v1`), authenticated with
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
- AC-003: the review agent's model is pinned to `opencode-zen/kimi-k3`; the
  endpoint is `https://opencode.ai/zen/v1`; auth is `OPENCODE_API_KEY`.
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
