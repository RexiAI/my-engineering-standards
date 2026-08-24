# ADR 0003: Provider-agnostic PR-review wiring

## Status

Accepted

## Context

ADR 0002 made general documentation provider-agnostic but deliberately left
the scoped PR-review integration vendor-specific: `agents/pr-review.md`
pinned `model: opencode-zen/kimi-k3` in frontmatter, the shared workflow
shipped a literal default model, and spec 024's gates (AC-024-01-02/-03/-04,
AC-024-05-01/-04) asserted those literals in agent config and docs.

Owner decision (2026-08-24): remove the last provider coupling. The project
is agnostic of CLI and provider everywhere — including the pr-review feature.

While this ADR was in review, `179b494` landed on main and moved the reviewer
into the standard roster: `opencode.json` gained a `pr-review` agent entry
resolving `{env:SPEC_PR_REVIEW_MODEL}` (roster extended 8 -> 9), removing the
frontmatter pin from the config side. This ADR adopts that mechanism and
finishes the job on the workflow/docs side.

Runtime fact that made the original pin cheap to remove: the shared workflow never runs
`--agent pr-review` (frontmatter `mode: subagent` makes opencode reject it);
it embeds the agent's instructions in a prompt and passes an explicit
`--model`. The frontmatter pin was therefore decorative at runtime while
still forcing every consumer into one vendor.

## Decision

1. `agents/pr-review.md` ships without a `model:` key — no exceptions to the
   "agents ship without model:" rule anymore.
2. The shared workflow's model comes solely from the `PR_REVIEW_MODEL`
   repository variable; the shipped literal default is removed. Unset
   variable ⇒ review skips cleanly (same semantics as an unset API key).
   Opting in = configuring both key and model.
3. The reviewer stays a roster agent per `179b494`: `pr-review` resolves
   `{env:SPEC_PR_REVIEW_MODEL}` like every other agent; provider blocks remain
   operator configuration (endpoint/auth/model lists) per ADR 0002. The
   workflow's remaining literal fallback model is deleted — when neither the
   repo variable nor an override is set, the committed example default applies
   (standard override chain), so no model id ships in tracked non-config files.
4. Gates rewritten: AC-020-01-01 (selftest) now requires EVERY shipped agent
   to ship without `model:`; AC-024-01-02 inverts to forbid any `model:` key;
   AC-024-01-03 checks provider wiring stays out of the agent block;
   AC-024-01-04 forbids model ids in the agent file; AC-024-05-01/-04 assert
   the neutral docs (`PR_REVIEW_MODEL`, secret name, cross-reference)
   instead of vendor literals. `docs/SPEC_PIPELINE.md §Using OpenCode Zen`
   becomes `§PR review model wiring`.
5. The `OPENCODE_API_KEY` secret/env name is kept for compatibility with
   already-configured child repos; it is an identifier, not vendor prose.

## Consequences

- Gate catalog changed (AC-020-01-01, AC-024-01-02/-03/-04, AC-024-05-01/-04,
  SPEC_PIPELINE section heading); this ADR satisfies GOVERNANCE's
  review-blocking ADR requirement.
- Child repos that opted in AND relied on the shipped default must now set
  the `PR_REVIEW_MODEL` repo variable once; repos relying only on skip
  semantics are unaffected.
- Rejected alternative: keep the pin and scrub only prose — rejected because
  a tracked vendor-pinned model is exactly the coupling being removed, and
  the runtime never read the pin anyway.
