# Voice Console

The voice console is an operator surface for a running orchestrator session. It
speaks assistant text from one parent session, listens for operator speech, and
— only when explicitly opted in — answers questions and permission requests
under the never-list policy.

The console is **half-duplex**: it either listens or speaks, never both at once.
Full-duplex operation is out of scope and is not supported.

## Modes

- `narrate` — speak assistant text from the parent session named by
  `--session`. Narrate constructs no capture adapter and no speech-recognition
  adapter.
- `converse` — capture an utterance, transcribe it locally, send it as a prompt
  to the parent session, and speak the reply. Without `--session` the console
  creates a session with `--agent` (default `voice-concierge`).
- `control` — opt-in gated control. The console speaks numbered question options
  and permission summaries, and replies only after the required confirmation.
  In `narrate` and `converse`, question and permission events are recorded as
  `ignored` and nothing is sent.

Audio never leaves the machine. Local recognition is the default. The Bailian
path is an optional fallback restricted to URL or long audio, and it requires a
standard `sk-` key; it is never used by the default file modes.

## Install

The console is opt-in. Nothing is installed into the default agent set.

```sh
make install-voice     # agents-optional/voice-concierge.md + scripts/voice/*
make uninstall-voice   # remove exactly the installed paths
make smoke-voice       # structural smoke: no network, no weights, no audio device
```

`scripts/voice/install.mjs` copies the agent to
`$OPENCODE_CONFIG_DIR/agents/voice-concierge.md` and the bridge to
`$OPENCODE_CONFIG_DIR/voice/`. `OPENCODE_CONFIG_DIR` defaults to
`~/.config/opencode`. A second run is idempotent; `--uninstall` removes only the
installed paths; `--dry-run` prints every destination and writes nothing.

## Headless file modes

Every audio path has a file-based mode so CI needs no sound card:

| Purpose | Flag | Behaviour |
|---|---|---|
| Capture | `--audio-in file:PATH` | read a 16 kHz mono s16le WAV |
| Capture | `--audio-in device` | spawn `arecord -f S16_LE -r 16000 -c 1 -t raw` |
| Playback | `--audio-out file:DIR` | write `NNNN.wav`, never overwrite |
| Playback | `--audio-out device` | `ffplay -nodisp -autoexit -loglevel quiet <path>` |
| Recognition | `--asr file:PATH` | line N is the transcript of utterance N |
| Speech | `--tts-engine silent` | synthesise a WAV with no third-party import |
| Events | `--events FILE` | read the event stream from a file instead of a socket |
| Commands | `--input-script FILE` | supply operator lines without a terminal |

A missing `arecord` or `ffplay` is a dependency failure (exit 3), never a
silent success. File modes spawn no child process.

## Configuration

Precedence is flag > environment variable > default.

| Setting | Flag | Environment | Default |
|---|---|---|---|
| Mode | `--mode` | `VOICE_MODE` | `narrate` |
| Parent session | `--session` | `VOICE_SESSION` | unset |
| Agent for a new session | `--agent` | — | `voice-concierge` |
| opencode base URL | `--opencode-url` | `VOICE_OPENCODE_URL` | `http://127.0.0.1:4096` |
| Artifacts directory | `--artifacts` | `VOICE_ARTIFACTS_DIR` | `.cache/voice/runs/default` |
| ASR engine | `--asr-engine` | `VOICE_ASR_ENGINE` | `faster-whisper` |
| Capture | `--audio-in` | — | `device` |
| Playback | `--audio-out` | — | `device` |
| TTS engine | `--tts-engine` | — | `pocket-tts` |
| Sentence budget | `--max-sentences` | — | `3` |
| Seconds budget | `--max-seconds` | — | `45` |
| Model cache | — | — | `.cache/voice/models` |

`--print-config` prints one JSON object with these values and performs no I/O:
no socket, no model load, no file write.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | ok |
| `2` | usage error |
| `3` | missing runtime or dependency |
| `4` | policy refusal |
| `5` | upstream or transport failure |

## Never-list

The classifier in `scripts/voice/policy.mjs` enforces these rules, in order:

1. `merge`
2. `tag`
3. `push-main`
4. `force-push`
5. `delete-branch`
6. `gate-threshold`
7. `secret-rotate`
8. `write-outside-repo`
9. `git-init`

A refusal is printed as `refused: <rule>` and cannot be overridden by any flag.

## Speech budget

Each turn speaks at most three sentences and at most 45 seconds, estimated at
2.5 words per second. Whole sentences only: a sentence is never truncated. The
first sentence is always spoken even if it alone exceeds the time estimate.
Deferred sentences are stored and spoken when the operator says `more`. `stop`
cancels the current utterance; `repeat` speaks the last window again.
`nothing-more` records a request after exhaustion without writing audio.

## Speech recognition

The shipped default is `faster-whisper`, exported as `ASR_DEFAULT_ENGINE` from
`scripts/voice/config.mjs`. The documented alternative is `sherpa-onnx`. Both
are local engines; the module contains no cloud path. When the selected engine's
package is absent the adapter exits 3 with `missing-runtime` before reading any
audio.

## Licensing and weights

Model weights are **not redistributed** with this repository. The worker and the
model cache (`.cache/voice/models`) download nothing during install or smoke.
If you fetch a model yourself, its Hugging Face model-card terms govern your
use, including the model card's prohibited-use clause on voice cloning. Do not
clone a voice without the speaker's explicit consent, and do not use a cloned
voice to impersonate or deceive.

## API mapping

`scripts/voice/opencode-client.mjs` is the only implementation of this table;
`scripts/tests/voice-fake-server.mjs` is its executable contract.

| Operation | Method | Path | Body |
|---|---|---|---|
| Event stream | `GET` | `/event` | — (newline-delimited JSON) |
| Create session | `POST` | `/session` | `{"agent":"voice-concierge"}` |
| Send prompt | `POST` | `/session/{sessionID}/message` | `{"parts":[{"type":"text","text":"…"}]}` |
| Answer question | `POST` | `/question/{id}/reply` | `{"label":"…"}` or `{"text":"…"}` |
| Answer permission | `POST` | `/permission/{id}/reply` | `{"reply":"once"}` |

## Troubleshooting

- `exit 3` naming `arecord` — install ALSA utilities or use `--audio-in file:`.
- `exit 3` naming `ffplay` — install FFmpeg or use `--audio-out file:DIR`.
- `exit 3` with `missing-runtime` — install the selected local ASR engine, or
  pass `--asr file:PATH` for a deterministic transcript.
- `exit 4` with `refused: <rule>` — the intent is on the never-list. No flag
  overrides it; ask the owning pipeline stage to act instead.
- `exit 5` — the opencode endpoint failed twice for one request, or the event
  stream failed three reconnect attempts. Check `--opencode-url`.
- No audio files — check `--audio-out` and the `--artifacts` directory. The
  ledger is `ledger.jsonl`; audio is `audio/NNNN.wav`.
