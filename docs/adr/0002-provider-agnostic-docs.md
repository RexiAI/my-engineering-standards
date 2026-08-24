# ADR 0002: Provider-agnostic general documentation

## Status

Accepted

## Context

Spec 024 pinned the PR-review integration (agent frontmatter `model:` pin,
provider endpoint, CI secret) and its gates assert those literals inside the
scoped operator sections (`docs/SPEC_PIPELINE.md §Using OpenCode Zen`,
`docs/CI_CD.md §PR Review Agent`). Spec 025 moved per-agent model assignment to
`{env:SPEC_*_MODEL}` references plus config-file defaults, and its selftest
(AC-025-07-02) still required `AGENTS.md` to repeat the concrete default model
ids — a leftover of the pre-025 mirror-table design.

Owner decision (2026-08-24, PR #52 review): general documentation must be
CLI-agnostic and provider-agnostic. Broadcasting concrete model ids in
`AGENTS.md` made every machine-specific choice look like a repo-wide decision
and caused repeated doc/gate conflicts when machines differ.

## Decision

1. General docs (`AGENTS.md`, `docs/GOVERNANCE.md`, the general part of
   `docs/SPEC_PIPELINE.md §Model configuration`) carry **no** concrete model or
   provider ids. They describe the mechanism and point at
   `config/model.local.env.example` for defaults.
2. `AC-025-07-02` is inverted: it now asserts AGENTS.md documents the dotenv
   flow AND carries no model/provider ids.
3. Governance gate `AC-010-04-03/-04` are rewritten: the mirror-table /
   same-commit rules are replaced by the no-docs-mirror rule (docs never mirror
   assignments; switching a model is a local config edit).
4. Scoped operator sections for the opt-in PR-review integration keep their
   wiring facts (endpoint URL, env var name, pinned model id): they document a
   real third-party setup a human must perform, and their gates
   (`AC-024-05-01/-04`) stay unchanged.

## Consequences

- Per-machine model changes never require doc edits or PRs.
- Gate catalog changed for AC-010-04 and AC-025-07-02 (this ADR satisfies the
  review-blocking ADR requirement of `docs/GOVERNANCE.md §ADR Requirement`).
- Rejected alternative: keep the literal mirror table and update its values per
  model change — rejected because it re-couples general docs to vendor ids and
  recreates the same-commit drift class the rule exists to prevent.
