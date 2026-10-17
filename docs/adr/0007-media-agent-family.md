# Architecture Decision Record (ADR)

## Title

Media agent family: global opencode agents driving the Bailian `bl` CLI, with a URL-chained pipeline and a separate realtime voice app

## Status

Accepted

## Context

The user runs opencode (TUI on this Linux box, opencode desktop on Windows)
with an Aliyun Bailian **Token Plan** subscription. The plan's hosted
text-model wire formats (Anthropic-style and OpenAI-compatible endpoints) are
already wired as the `bailian-token-plan-personal` provider, but the plan also
entitles several *media* models —
image (qwen-image-3.0-pro, wan2.7-image), video (wan3.0-video, happyhorse-1.1
t2v/i2v/r2v), speech (qwen-audio-3.0-tts-plus / -asr-flash / -realtime-plus).
Those are not chat-completion models an opencode provider block can call; they
are reached through the `bl` CLI, which is Node-based and therefore cross-
platform. Media production must work identically on both machines, survive
`git pull` updates, and obey the repo's governance (no pinned models in agent
frontmatter, no hardcoded secrets, ADR for new roles, confirm-before-spend).

Two constraints were established empirically on 2026-10-16 (probe record in
`docs/MEDIA_AGENTS.md §Feature matrix`):

- The Token-Plan harness key (`sk-sp-…`) authenticates `bl`'s media commands
  **except** anything that uploads a local file through DashScope temporary
  storage, and **not at all** on the realtime WebSocket (`api-ws/v1/realtime`,
  `InvalidApiKey` on all regional hosts). `qwen-audio-3.0-realtime-plus` is
  WS-only — it 400s on the HTTP path.
- `bl` media commands return **remote output URLs** alongside local files, and
  accept remote URLs as inputs.

## Decision

- Add four global agents to `agents/` (`media-image`, `media-video`,
  `media-voice`, `media-producer`), `mode: all`, no `model:` pin (inherit the
  user's primary model per machine, per Model-Assignment Discipline). They
  wrap `bl`/`ffmpeg` behind per-agent permission allowlists and a uniform
  confirm-before-spend gate (video batch = explicit approval; producer =
  storyboard gate).
- **URL-chaining is the pipeline contract**: every agent brief must carry the
  remote output URL of an upstream asset rather than a local path, because the
  Token-Plan key cannot upload. Local paths remain supported when the user
  configures a standard DashScope `sk-` key.
- Ship `scripts/media/voice-chat/` — a zero-dependency Node ≥ 22 full-duplex
  realtime voice app (mic → WS → speaker via ffmpeg/ffplay, OpenAI-realtime
  event protocol) that requires a standard `sk-` key and refuses `sk-sp-` with
  a diagnostic. Turn-based voice (ASR→reply→TTS loop via `bl`) covers realtime-
  ish chat on Token-Plan keys alone; the app is the upgrade path, not a hard
  dependency.
- Distribution: `scripts/media/install.mjs` copies agents into the opencode
  global dir (`~/.config/opencode/agents/`, `%USERPROFILE%\.config\opencode`
  on Windows) and the voice app into `~/.config/opencode/media/`. The repo
  stays the single source of truth; `make install-media` and
  `scripts/bootstrap-windows.ps1` cover both machines.
- `scripts/media/smoke-media.mjs` validates structure and `bl --dry-run`
  command construction without spending credits; live checks are manual and
  opt-in.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| opencode custom tools (plugin) per media type | typed arguments, no shell | forks vendor CLI semantics; plugin API surface larger than needed |
| Bash scripts + WSL on Windows | reuses Linux tooling | user wants native opencode desktop; WSL adds a second filesystem/credential surface |
| One monolithic media agent | fewer files | permission blast radius, weaker prompt focus, loses delegation parallelism |
| Pin media-agent models (`model:`) | explicit cost control | forbidden by Model-Assignment Discipline; per-machine env not portable to Windows (no direnv) |

## Consequences

- Media agents are available in every project (global install) — accepted;
  they are machine capabilities, not project structure.
- Full-duplex voice on Windows/Linux requires the user to obtain a standard
  DashScope key; without it the feature matrix degrades to turn-based voice
  and URL-input ASR. Documented in `docs/MEDIA_AGENTS.md`.
- `bootstrap.sh` child installs now also carry the four media agents —
  harmless (they never touch git remotes; permissions are narrow).
- The no-upload constraint is a vendor-auth limitation, not ours: a Token-Plan
  change could silently restore local-path support; the smoke suite's live
  (opt-in) mode would detect it.

## Compliance

- `scripts/media/smoke-media.mjs` in `make ci` fast ladder (structure +
  dry-run), bats file `scripts/tests/media-agents.bats`.
- `scripts/check-no-hardcoded-secrets.sh` covers all added files (no key
  literals; creds only via env/bl profile).
- `scripts/check-governance.sh` — media agents carry T1 rows in the trust-tier
  mapping; T3 prohibitions restated in their frontmatter (`git push*` deny).

## Notes

- 2026-10-16: Decision recorded (probe data same day).
