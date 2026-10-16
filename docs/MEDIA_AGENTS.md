# Media Agents

Machine-level media production for opencode (Linux + Windows): four global
agents plus a realtime voice app, all driving the Bailian CLI (`bl`) against a
Token Plan subscription. Architecture decision: `docs/adr/0007-media-agent-family.md`;
trust tiers and model-assignment rules: `docs/GOVERNANCE.md`.

## Components

| Component | Path | Role |
|---|---|---|
| `media-image` | `agents/media-image.md` | text→image, image edit/merge |
| `media-video` | `agents/media-video.md` | t2v / i2v / kf2v / reference-to-video / edit, ffmpeg assembly |
| `media-voice` | `agents/media-voice.md` | TTS, ASR, turn-based voice chat, realtime launcher |
| `media-producer` | `agents/media-producer.md` | storyboard-gated end-to-end video pipeline; delegates to the three above |
| voice-chat app | `scripts/media/voice-chat/` | full-duplex realtime voice (Node ≥ 22, WS) |
| installer | `scripts/media/install.mjs` | copies agents + app into the opencode global dir |
| smoke | `scripts/media/smoke-media.mjs` | structure + `bl --dry-run` validation, zero credits |

Model choice inside every agent is *bl profile default or user-named*; the
agents themselves inherit your primary opencode model (never pinned in
frontmatter — governance rule, see `docs/GOVERNANCE.md §Model-Assignment
Discipline`).

## Feature matrix (Token-Plan key, probed 2026-10-16)

| Capability | Command surface | Token-Plan `sk-sp-` key | Notes |
|---|---|---|---|
| Text/image/vision chat | `bl text chat`, `bl omni --text-only` | ✅ | provider + CLI both wired |
| Image generate | `bl image generate` | ✅ | returns local file **and** remote URL |
| Image edit | `bl image edit` | ✅ with URL input | local `--image` path needs upload → ❌ |
| TTS | `bl speech synthesize --model qwen-audio-3.0-tts-plus --voice longanqian` | ✅ | `--voice` is required |
| ASR | `bl speech recognize --model qwen-audio-3.0-asr-flash` | ✅ URL input | local file ❌ (upload policy 401); one ≤5 min file per sync call |
| Video generate/ref | `bl video generate / ref` (async task) | ✅ | most expensive call — confirm before spend |
| Local-file upload (any) | implicit `oss://` temp storage | ❌ | the single auth gap for file inputs |
| Realtime voice WS | `api-ws/v1/realtime` (`voice-chat.mjs`) | ❌ | `sk-sp-` rejected on all regional hosts; model is WS-only (400 on HTTP) |

Two ways to close the ❌ rows: a **standard DashScope `sk-` API key** (exported
as `BAILIAN_API_KEY` / `DASHSCOPE_API_KEY`, or configured in a second `bl`
profile), or keep **URL-chaining** as the pipeline contract — every generated
asset's remote URL is passed to the next stage instead of a local path.

## Install

```bash
# Linux/macOS (and any shell with node):
make install-media        # or: node scripts/media/install.mjs
# restart opencode — the four agents appear as primary agents and as subagents

# Uninstall:
node scripts/media/install.mjs --uninstall
```

Windows (clean machine): open PowerShell,

```powershell
cd $HOME\my-engineering-standards   # after git clone (see below)
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-windows.ps1
```

`bootstrap-windows.ps1` is idempotent: Node LTS, git, ffmpeg (winget),
`bailian-cli` (npm), `bl skill init`, `bl auth login` (prompts; stores
`OPENCODE_API_KEY`, and `BAILIAN_API_KEY`/`DASHSCOPE_API_KEY` when a standard
key is entered), clone/pull this repo, run the installer, run the smoke.
Install opencode desktop separately from the official site if winget does not
offer it.

## Typical flows

- **Poster:** ask `media-image` → confirm → one `bl image generate`.
- **Narration:** ask `media-voice` (TTS) or feed it a script file.
- **Short video:** ask `media-video` with a shot idea; it confirms model,
  duration, resolution, count **before** rendering.
- **End-to-end:** `media-producer` — brief → storyboard gate → keyframes →
  clips → narration → `final.mp4` under `out/media/productions/<slug>/`.
- **Live voice conversation:** `media-voice` runs the turn-based loop on a
  Token-Plan key; with a standard key it can launch
  `node ~/.config/opencode/media/voice-chat/voice-chat.mjs` for full-duplex.

## Troubleshooting

- `InvalidApiKey` at "get upload policy" → you used a **local path** with a
  Token-Plan key. Pass the remote URL (or a standard key).
- `Missing required flag: --voice` → run `bl speech synthesize --list-voices
  --model <id>`; `longanqian` is a safe default for the 3.0-TTS family.
- realtime `401 InvalidApiKey` on WS → key type, not the key: WS needs a
  standard `sk-`.
- Windows mic silent → `--list-devices`, pass the exact `--device` name
  (dshow requires it).
- Flags ever in doubt: `bl <command> --help` (authoritative), never guesses —
  same rule as the `bailian-gen` skill protocol.
- Watermarks are on by default (`bl config set --key watermark --value false`
  to change profile state; ask the user first).

## Testing

`scripts/tests/media-agents.bats` (in `make test`) checks frontmatter shape,
no pinned models, voice-chat syntax, and smoke exit. Live smoke is manual:
`node scripts/media/smoke-media.mjs`, then opt-in real generations via the
agents themselves.
