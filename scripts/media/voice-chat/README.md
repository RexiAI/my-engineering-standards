# voice-chat — full-duplex realtime voice chat

Node ≥ 22, zero dependencies. Mic → DashScope Qwen-Audio Realtime WebSocket →
speaker, with server-side VAD (interrupt the model by talking; Ctrl-C exits).

## Requirements

- **A standard DashScope API key (`sk-...`).** Token-Plan harness keys
  (`sk-sp-...`) are rejected by the realtime WebSocket endpoint
  (`InvalidApiKey` — probed 2026-10-16). Turn-based voice keeps working with
  Token-Plan keys; this app is the one capability that needs the other key type.
- `ffmpeg` and `ffplay` on PATH (Windows: `winget install Gyan.FFmpeg`).

## Run

```bash
# Set BAILIAN_API_KEY (or pass --api-key) to your standard DashScope key first:
node voice-chat.mjs                  # defaults: qwen-audio-3.0-realtime-plus, voice longanqian
node voice-chat.mjs --model qwen-audio-3.0-realtime-flash --voice longanlingxin
node voice-chat.mjs --beijing        # use the Beijing WS host instead of intl
node voice-chat.mjs --list-devices   # Windows: show dshow microphones, then --device "<name>"
```

Linux captures ALSA `default`; Windows requires `--device "<mic name>"`
(dshow); macOS uses avfoundation names/indices. Transcripts print to stdout.
Without `ffplay`, replies are written to `out/media/voice/last-reply.wav`.
