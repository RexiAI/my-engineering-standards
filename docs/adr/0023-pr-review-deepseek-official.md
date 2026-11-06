# 0023 — PR review defaults to DeepSeek official

## Status

Proposed

## Context

ADR 0003 removed the last provider pin from PR review: the shared workflow took
its model only from the `PR_REVIEW_MODEL` repository variable and its key from
`OPENCODE_API_KEY`, with no shipped default. That kept the feature
provider-agnostic but made it inert for any repo that had not configured the
variable — and the self-hosted trigger on this repo had no variable set, so the
review ran against the opencode Zen default and failed every PR with
`AI_APICallError: Invalid credential`.

Owner decision (2026-11-06): the review should work out of the box on this repo,
using the DeepSeek official API and a `DEEPSEEK_API_KEY` secret, while keeping
the override path for other providers and for already-configured child repos.

## Decision

1. `opencode.json` ships a `deepseek` provider block at the end of the file:
   `https://api.deepseek.com/v1`, `DEEPSEEK_API_KEY`, and the models
   `deepseek-flash` (default) and `deepseek-v4-pro`. The provider block stays
   operator configuration; only the PR-review default is committed.
2. `config/model.local.env.example` sets `SPEC_PR_REVIEW_MODEL=deepseek/deepseek-flash`.
   It is the one non-placeholder value in that file; every pipeline seat remains
   a placeholder.
3. The shared workflow defaults `SPEC_PR_REVIEW_MODEL` to
   `deepseek/deepseek-flash` when the resolved value is empty or still the
   `your-provider/*` placeholder. `PR_REVIEW_MODEL` still wins, and a real
   `SPEC_PR_REVIEW_MODEL` from the caller's env is never overwritten.
4. `DEEPSEEK_API_KEY` is the primary review secret (`workflow_call` + this
   repo's trigger). `OPENCODE_API_KEY` stays declared and mapped for an explicit
   non-DeepSeek `PR_REVIEW_MODEL` override, preserving ADR 0003 decision 5's
   compatibility promise. `init-ci.sh` child wiring is deliberately unchanged
   here: it still pins the pre-change workflow by SHA, so passing the new secret
   before that pin moves would make the reusable-workflow call fail to start.
   The pin bump and the child wiring land together in a follow-up.
5. The self-hosted trigger calls the reusable workflow by local path
   (`./.github/workflows/ci-pr-review.yml`) instead of a SHA pin, so this
   repo's PRs exercise exactly the workflow revision in the same commit. Child
   repos keep the SHA-pinned remote reference (supply-chain rule); the local
   path is not a branch reference and cannot drift.
6. A rejected credential (`Invalid credential`, `invalid api key`,
   `unauthorized`, `authentication`, `401`) joins the provider-side skip guard:
   the review skips with a warning instead of failing the PR. Auth is not a code
   defect, and the review check is advisory.
7. Gates updated in `scripts/check-pr-review.sh`: the provider block must map a
   supported review key by env reference, the `deepseek` block must carry the
   official endpoint and default model, both secrets must be declared optional,
   the trigger must map both secrets and call the local workflow, and the
   workflow must carry the auth-skip phrases. No gate is weakened; each
   assertion is tightened to cover the new default.

## Alternatives Considered

- **Keep ADR 0003's no-default rule and require `PR_REVIEW_MODEL` everywhere.**
  Rejected: it leaves this repo's review dead until a human sets a variable, and
  that silent skip is what allowed an invalid credential to fail every PR.
- **Pin `deepseek-v4-pro` as the default.** Rejected for cost: review is an
  advisory, comment-only pass; `deepseek-flash` is the cheaper sufficient tier.
  The pro model remains one `PR_REVIEW_MODEL` value away.
- **Drop `OPENCODE_API_KEY` entirely.** Rejected: already-configured child repos
  would break, and a non-DeepSeek override needs a key path.
- **Keep `opencode-zen/deepseek-v4.1-flash-free`.** Rejected: the credential was
  invalid and the free model is not an official DeepSeek endpoint; the owner
  asked for the official API.

## Consequences

- The self-hosted review works when `DEEPSEEK_API_KEY` is present, with no repo
  variable required. Child repos on the `your-provider/*` placeholder inherit
  the same default; child repos with a real custom model keep it.
- ADR 0003 decisions 2 and 3 ("no shipped default model", "opting in = key and
  model") are superseded for the default provider. Decision 5 (keep
  `OPENCODE_API_KEY` for compatibility) still holds.
- Self-hosting needs no pin bump: the trigger calls the local workflow, so this
  repo's next PR event runs this revision. Child repos still pin the shared
  workflow by SHA and stay on the previous revision until the follow-up moves
  the pin and adds the `DEEPSEEK_API_KEY` mapping to `init-ci.sh`.
- Follow-up scope is larger than a pin bump. A bootstrapped child also needs
  (a) the `deepseek` provider block in `templates/opencode.json.bridge` — without
  it the new default resolves to "Model not found" — and (b) the
  `.standards/config/model.local.env.example` fallback the workflow now carries,
  because a child has no top-level `config/` example. Both are recorded here so
  the child change is not mistaken for a one-line pin edit.
- A provider auth failure now produces a skipped check, not a red one. That is
  the intended contract for an advisory, comment-only review, and it is recorded
  in the run's warning rather than hidden.

## Compliance

`docs/GOVERNANCE.md §ADR Requirement` — this changes the PR-review provider
wiring and the gate catalog (`scripts/check-pr-review.sh`), so the ADR is
review-blocking. `scripts/check-pr-review.sh`, `scripts/check-model-env.sh`, and
`scripts/check-no-hardcoded-secrets.sh` remain green; only secret names, never
values, appear in tracked files.

## Notes

- 2026-11-06: introduced with the merge of 043-agent-eval-harness, after PR 121
  surfaced the invalid-credential failure on the self-hosted review.
- Endpoint and model ids verified against `GET https://api.deepseek.com/models`
  on 2026-11-06: `deepseek-flash` (DeepSeek-V4.1-Flash) and `deepseek-v4-pro`
  (DeepSeek-V4-Pro), both 1,048,576-token context / 393,216-token output.
