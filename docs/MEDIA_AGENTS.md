# Media Agents

Machine-level media production for opencode (Linux + Windows): four agents that
drive a **user-configured backend contract**. This repo ships no provider, no
vendor CLI, and no model ids — you point the agents at whatever image, video,
TTS, and ASR commands your machine has. Architecture decisions:
`docs/adr/0016-provider-agnostic-media-agents.md` (the contract) and
`docs/adr/0018-media-agents-opt-in.md` (placement and opt-in); trust tiers and
model-assignment rules: `docs/GOVERNANCE.md`.

The family is **not loaded by default in child repos**: the files live in
`agents-optional/`, outside the `agents/` tree a child's `.opencode/agents`
wiring links. See §Opt-in below for the two ways to load them.

## Components

| Component        | Path                                | Role                                                                     |
| ---------------- | ----------------------------------- | ------------------------------------------------------------------------ |
| `media-image`    | `agents-optional/media-image.md`    | text→image, image edit/merge                                             |
| `media-video`    | `agents-optional/media-video.md`    | t2v / i2v / first+last-frame / edit, ffmpeg assembly                     |
| `media-voice`    | `agents-optional/media-voice.md`    | TTS, ASR, turn-based voice chat                                          |
| `media-producer` | `agents-optional/media-producer.md` | storyboard-gated end-to-end video pipeline; delegates to the three above |
| installer        | `scripts/media/install.mjs`         | copies agents + the backend example into the opencode global dir         |
| smoke            | `scripts/media/smoke-media.mjs`     | structure + contract validation, zero network, zero spend                |
| contract example | `scripts/media/backends.example.json` | the argv shape every agent reads                                       |

Agents inherit your primary opencode model and never pin one in frontmatter
(governance rule, see `docs/GOVERNANCE.md §Model-Assignment Discipline`).

## Opt-in

The family loads in exactly two ways, both explicit. Nothing is placed under a
child's `.opencode/` — that path is a symlink to the whole standards agent
tree, so the per-repo opt-in names the files instead.

A flagless run and `--none` leave the family out; `--all` selects it like any
other non-baseline capability, so a child bootstrapped with `--all` does carry
the four entries below.

The directory sits outside the orchestration gate on purpose:
`scripts/check-orchestration.sh` scans `agents/` and `commands/`, and resolves
the references it finds against **this** repo's tree. Files in `agents-optional/`
are instead reached from a child's `opencode.json` through
`.standards/agents-optional/…`, whose paths resolve inside the submodule — so
scanning them here would judge them against the wrong root.

**Global (machine-wide).** `make install-media` copies the four agents from
`agents-optional/` into `~/.config/opencode/agents/`, where they load in every
opencode session on this machine. This is the right choice when media work is a
machine capability you use from several repos. `make uninstall-media` removes
them again.

**Per repo.** `./.standards/scripts/bootstrap.sh --with-media` (or `--all`)
writes four `agent` entries into the child's own `opencode.json`, each pointing
at the standards submodule:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "media-image": { "prompt": "{file:.standards/agents-optional/media-image.md}" },
    "media-video": { "prompt": "{file:.standards/agents-optional/media-video.md}" },
    "media-voice": { "prompt": "{file:.standards/agents-optional/media-voice.md}" },
    "media-producer": { "prompt": "{file:.standards/agents-optional/media-producer.md}" }
  }
}
```

Only those four keys are added: your existing `agent` entries, model pins, and
every other key are preserved, a re-run is a no-op, and an `opencode.json` that
is not plain JSON (comments) is left untouched with a WARN naming the manual
step. Removing the four keys (or `make uninstall-media` for the global install)
opts that repo back out. Either way the backend contract itself still has to
exist — the agents stop and name a missing section rather than guessing.

## Backend contract

The agents read `~/.config/opencode/media/backends.json`, or the path in
`MEDIA_BACKENDS_FILE` when that is set. `make install-media` installs the
example and creates `backends.json` from it only when no config exists;
re-running never overwrites your edited file.

```json
{
  "image": {
    "generate": ["<your-image-cli>", "generate", "--prompt", "{prompt}", "--out", "{out}"],
    "edit": ["<your-image-cli>", "edit", "--image", "{image}", "--prompt", "{prompt}", "--out", "{out}"]
  },
  "video": {
    "generate": ["<your-video-cli>", "generate", "--prompt", "{prompt}", "--out", "{out}"],
    "status": ["<your-video-cli>", "task", "get", "{task_id}"]
  },
  "tts": { "command": ["<your-tts-cli>", "--text", "{text}", "--voice", "{voice}", "--out", "{out}"] },
  "asr": { "command": ["<your-asr-cli>", "--audio", "{audio}"] }
}
```

Each operation is an argv array. The agent substitutes the placeholders it
actually needs and executes the array through its permission layer. Supported
placeholders:

`{prompt}`, `{image}`, `{image_2}`, `{image_3}`, `{last_frame}`, `{video}`,
`{out}`, `{size}`, `{count}`, `{model}`, `{text}`, `{voice}`, `{audio}`,
`{language}`, `{duration}`, `{resolution}`, `{task_id}`.

Rules the agents follow:

- Missing section or operation → stop and name it. They never guess a flag or
  substitute a different command.
- An optional `notes` string per section documents backend-specific facts
  (local path vs URL inputs, format limits, how to list voices).
- Credentials belong to the configured command (its own env vars or credential
  store). Never put a key in `backends.json` or in an agent prompt.
- Commands outside the agent allow-list are prompted by the permission layer;
  the agents never bypass it.

## Install

```bash
make install-media          # or: node scripts/media/install.mjs
# edit ~/.config/opencode/media/backends.json — replace the <angle-bracket> commands
# restart opencode — the four agents appear as primary agents and as subagents

make uninstall-media        # removes the agents + example; keeps backends.json
```

Windows (clean machine):

```powershell
cd $HOME\my-engineering-standards   # after git clone
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-windows.ps1
```

`bootstrap-windows.ps1` is idempotent: Node LTS, git, ffmpeg (winget),
clone/pull this repo, run the installer, run the smoke. Install opencode
desktop separately if winget does not offer it.

## Typical flows

- **Poster:** ask `media-image` → confirm → one configured `image.generate`.
- **Narration:** ask `media-voice` with text; it calls `tts` and plays the file.
- **Short video:** ask `media-video` with a shot idea; it confirms duration,
  resolution, and clip count **before** rendering.
- **End-to-end:** `media-producer` — brief → storyboard gate → keyframes →
  clips → narration → `final.mp4` under `out/media/productions/<slug>/`.

## Troubleshooting

- "backends.json not found" → run `make install-media`, then edit the file.
- "missing `video.generate`" → the agent refuses to guess; add the argv your
  backend needs.
- Permission prompt before every generation → expected: arbitrary backend
  commands are not allow-listed, so the permission layer asks. Keep the ask;
  it is the spend gate.
- Backend rejects a local path → check that section's `notes`; some backends
  require a URL and handle uploads themselves.
- No realtime/full-duplex voice ships here. `media-voice` is turn-based; add a
  realtime app yourself if you want it.
- Flags ever in doubt: run the configured command with `--help` yourself; the
  agent never guesses.

## Testing

`scripts/tests/media-agents.bats` (in `make test`) checks frontmatter shape,
no pinned models, no vendor-specific tokens, the contract example, installer
idempotency, and smoke exit — all against `agents-optional/`.
`scripts/tests/ac-040-media-agents-optional.bats` covers the opt-in boundary:
the family is absent from the default agent set and from a child bootstrapped
without the flag, and `--with-media` writes (and re-runs over) the four
`opencode.json` entries. `make smoke-media` runs the structural smoke.
