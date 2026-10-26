# ADR 0011: Mechanical gate for model-agnostic agent definitions

## Status

Proposed

## Context

ADR 0002 made documentation provider-agnostic and ADR 0003 removed the last
vendor pin from this repo's shipped agents and PR-review wiring: agent `.md`
files ship **without** a `model:` key, and per-stage models resolve through the
consumer's `opencode.json` `{env:SPEC_*_MODEL}` roster or harness inheritance.

That convention was prose only, and it stopped at the repo boundary. On
2026-10-15 a consumer machine's **global agent catalog**
(`~/.config/opencode/agent/`, an ECC-style install of reviewer/resolver agents)
carried 27 files with literal frontmatter pins — 22 × one copilot-hosted opus
id, 3 × a copilot sonnet id, 2 × ollama tags. (Families only, deliberately:
this repo's hygiene gate `tests/AC-030-07.sh` forbids printing the literal ids
outside its allow-list, and this ADR must stay clean under it.) On a provider
that does not serve those ids, every invocation of a pinned agent failed with
`Model not found: …`, while unpinned agents ran fine. The failure mode is exactly the one ADR 0003 documented for shipped
agents — a frontmatter pin silently wins over project config, because
`.opencode/agents/` loads after `opencode.json` — reproduced one layer out, in
catalogs no repo gate looked at.

Two gaps follow: (1) nothing mechanically enforces the no-pin rule even on this
repo's own surface; (2) consumers who copy agent catalogs have no audit tool
and no stated rule for the copies.

## Decision

1. **Rule.** No agent definition on the standards surface — `agents/*.md`,
   `.opencode/agents/*.md`, and any catalog this repo documents installing —
   carries a `model:` frontmatter key. Resolution order stays: consumer
   `opencode.json` `{env:SPEC_*_MODEL}` roster, then harness inheritance.
2. **Gate.** `scripts/check-agent-models.sh` scans both agent directories
   (deduped by realpath, so submodule/symlink twins report once), fails with
   exit 1 on any `model:` key, and ships a `--self-test` fixture proof
   (pinned rejected, clean accepted, symlink not double-counted). Wired into
   the `validate` job of `.github/workflows/self-ci.yml` without
   `continue-on-error`, following the `check-ci-sweeper.sh` step pattern.
3. **Consumer catalogs.** Documented in `docs/SPEC_PIPELINE.md`
   §Model configuration: strip `model:` lines from catalog copies; the gate is
   the reference audit tool (`check-agent-models.sh <catalog-root>`). This repo
   cannot enforce files outside repos that consume it — the gate plus the doc
   is the honest boundary, same posture as ADR 0003's note on read-permission
   enforcement.

## Alternatives considered

- **Env-var references in frontmatter** (`model: {env:...}`): rejected — agent
  frontmatter is not the consumer's config surface; opencode resolves the
  roster from `opencode.json`, and a frontmatter env reference would still win
  over project config where both exist.
- **Allow-list of known providers**: rejected — vendor coupling by list
  maintenance; every new provider becomes a standards change.
- **Prose-only (status quo)**: rejected — the 2026-10-15 incident shows prose
  does not survive catalog copies.

## Consequences

- Shipped agents and CI stay vendor-neutral; a provider outage or a machine
  without a given vendor no longer breaks agent invocation by config drift.
- One more validate-job step; self-test keeps it honest.
- Consumer-side catalogs remain outside mechanical reach — documented, audited
  on demand, not silently trusted (mirrors ADR 0003's enforcement honesty).

## Compliance

- `scripts/check-agent-models.sh --self-test` in self-ci `validate`.
- `docs/SPEC_PIPELINE.md` §Model configuration carries the rule and the
  consumer-catalog procedure.
- Any future agent added to `agents/` fails CI immediately if it pins a model.
