# Architecture Decision Record (ADR)

## Title

Provider-agnostic media agent family: global opencode agents driving a user-configured backend contract

## Status

Accepted

## Context

The repo previously shipped a media agent family bound to one hosted CLI and
one vendor's model catalogue. That coupling made the family unusable without
that vendor, leaked vendor names and model ids into agent prompts and docs,
and contradicted the repo's provider-agnostic rule for general documentation
(ADR 0002) and its model-agnostic gate (ADR 0011). The vendor-specific
decision record was retired with the provider.

The capability itself is still useful: image generation, video generation,
speech synthesis, transcription, and end-to-end production belong in the same
agent layer as the rest of the machine's tooling. What must not survive is the
assumption that a particular vendor or command surface is present.

## Decision

- Keep the four agents in `agents/` (`media-image`, `media-video`,
  `media-voice`, `media-producer`), `mode: all`, with no `model:` pin. They
  inherit the user's primary model per machine (Model-Assignment Discipline).
- Define a **backend contract** file, `~/.config/opencode/media/backends.json`
  (overridable with `MEDIA_BACKENDS_FILE`), whose sections (`image`, `video`,
  `tts`, `asr`) map operations to argv arrays containing placeholders such as
  `{prompt}`, `{image}`, `{out}`, `{text}`, `{voice}`, `{audio}`, `{task_id}`.
- Agents resolve the contract at runtime. A missing file or operation is a
  stop condition with the missing key named — never a guessed flag, never a
  fallback command, never an invented upload step.
- Ship `scripts/media/backends.example.json` as the contract template. The
  installer creates `backends.json` from it only when absent; uninstall keeps
  the user's edited config.
- Keep `scripts/media/install.mjs` (agents + contract example) and
  `scripts/media/smoke-media.mjs` (structure + contract validation, no network,
  no spend). The vendor-specific realtime voice app is not shipped: realtime
  is an optional capability the user configures and launches themselves.
- Permissions: allow only local media tooling (`ffmpeg`, `ffprobe`, `ffplay`,
  `arecord`); everything else is `ask`, so an arbitrary backend command is
  confirmed at execution time. `git push*` and `rm -rf *` stay denied.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Keep one vendor CLI hardcoded | zero setup | vendor lock-in, unusable after switching providers, leaks vendor names into docs |
| Remove the agents entirely | smallest surface | loses a useful machine capability instead of decoupling it |
| One generic `media` agent | fewer files | loses delegation parallelism and narrow permission blast radius |
| Pin a provider/model in agent frontmatter | explicit cost control | forbidden by Model-Assignment Discipline; breaks per-machine swaps |
| Env-var-only configuration | no JSON file | many argv arrays do not fit env vars cleanly; weaker validation |

## Consequences

- The family works with any backend the user can express as an argv template;
  switching providers is a `backends.json` edit, not a code change.
- Setup has one extra step: fill in the contract after install. A missing or
  incomplete contract fails closed with a named key.
- Arbitrary backend commands trigger the permission prompt. Accepted: it is
  the spend gate, and it keeps the agent from acquiring a broad allow-list.
- No realtime voice app ships. Turn-based voice works through `tts`/`asr`;
  realtime remains a user-supplied capability.
- `docs/MEDIA_AGENTS.md` documents the contract and the agent behaviours;
  general docs still carry no provider or model ids.

## Compliance

- `scripts/media/smoke-media.mjs` validates agent frontmatter and the contract
  example, and rejects vendor-specific tokens.
- `scripts/tests/media-agents.bats` covers install/uninstall, the contract, and
  the vendor-token check.
- `scripts/check-governance.sh` — the four agents carry T1 rows in the
  trust-tier mapping; T3 prohibitions are restated in their frontmatter.
- `scripts/check-no-hardcoded-secrets.sh` covers all added files.

## Notes

- 2026-10-28: rewritten provider-agnostic. Supersedes the retired
  vendor-specific media decision; the retired record is no longer indexed.
