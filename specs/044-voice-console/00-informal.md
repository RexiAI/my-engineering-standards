# Voice console for the spec pipeline

## Problem

The spec pipeline is text-only. Every interaction with it — asking what stage a spec
reached, reading why the Verifier blocked, approving the human gate — means reading
markdown in a terminal. That is fine at a desk and useless when the operator is
away from the screen, mid-task, or visually occupied.

Kyutai's Pocket TTS (`https://github.com/kyutai-labs/pocket-tts`) makes local,
CPU-only, ~200 ms-first-chunk speech output cheap: no GPU, no cloud TTS bill, MIT
code, ~100M params (English variants down to 1.9M), and a streaming Python API with
a cancellation `threading.Event`.

We want a voice console on top of opencode's v2 HTTP API so the operator can hear
the pipeline and, with an explicit opt-in, answer its gates by voice.

## What we want

A local voice bridge that speaks pipeline output through Pocket TTS and accepts
spoken input through local speech recognition, driving an opencode session whose
agent is the spec pipeline.

Two capabilities, deliberately separable:

1. **Narrate (output only).** Speak the orchestrator's assistant text as it streams.
   No microphone, no speech recognition, no consent surface. Useful on its own.
2. **Converse (input + output).** Capture speech, transcribe locally, send the
   transcript to the session, speak the reply. Read-only by default.
3. **Gated control (opt-in).** Surface `question.asked` and `permission.asked`
   events as spoken questions with numbered options, and reply to them by voice.
   Mutating actions (starting `/spec` or `/build`, approving a push) require a
   second confirmation in the terminal UI, not voice alone.

## Decisions already taken (defaults; flag if wrong)

- **Speech recognition runs locally.** `docs/MEDIA_AGENTS.md` documents that a
  Token-Plan `sk-sp-` key cannot upload a local audio file, so `bl speech
  recognize` cannot transcribe a microphone recording without a standard `sk-` key.
  Local ASR is the default; the Bailian path stays an optional fallback for
  URL/long audio only.
- **Read-only by default.** Control is behind an explicit flag, never the default.
- **One narrator voice.** Per-subagent voice personas are out of scope.
- **Speech budget.** At most 3 sentences or ~45 seconds per turn by default; the
  operator can ask for the rest.
- **Speak the orchestrator, not the swarm.** Only top-level assistant text in the
  parent session is spoken. Subagent chatter arrives as subtask parts and is
  suppressed.

## Constraints

- **Opt-in install.** Follow the precedent of spec 040: the agent and the bridge are
  installed into the user's global opencode config by an explicit installer
  (`make install-voice`), not loaded by default in every child repo.
- **No new default test dependency.** Python, PyTorch, and Pocket TTS are an
  optional runtime; the repo's `make test` must stay green without them. Smoke
  tests are structural and download no model weights.
- **No pinned model ids.** The new agent must not carry a `model:` frontmatter key
  (ADR 0011); model choice resolves through the existing per-machine mechanism.
- **Never-list stays absolute.** The bridge must refuse merge, git tag, push to
  main/master, force-push, branch deletion, gate-threshold change, secret
  creation/rotation, writes outside the target repo, and `git init`/submodule
  scaffolding — enforced in code before any API call, not by prompt wording.
- **No realtime duplex.** Pocket TTS is not a conversational model and has no ASR.
  The console is half-duplex with voice-activity endpointing. Claiming full duplex
  would be a lie.
- **Headless-safe.** This development shell has no sound card (`arecord -l` reports
  no capture devices). Every audio path must have a file-based mode so it can be
  exercised in CI and on a headless host; real device audio is verified on the
  operator's desktop.
- **Licensing.** The repository is MIT; model weights carry their own Hugging Face
  card terms and a prohibited-use clause on voice cloning. Do not redistribute
  weights as part of this repo.

## Scope boundary

In scope: the TTS worker, the bridge (microphone, endpointing, ASR, opencode client,
sentence chunking, playback, cancellation), the read-only concierge agent, the
opt-in installer, the operator documentation, and the structural smoke test.

Out of scope: wake-word detection, full-duplex barge-in conversation, per-agent
voices, word-level timestamp highlighting, any cloud TTS/ASR service, and any
change to the spec pipeline's own stages or gates.

## Open questions for the reviewer

- Which local ASR engine: `faster-whisper` (CTranslate2, int8) or `sherpa-onnx`?
  Pick one as the shipped default; the other stays a documented alternative.
- Should the concierge be a **separate primary agent** (`voice-concierge`,
  read-only, short spoken answers) or reuse `spec-pipeline` with a spoken-answer
  system prompt? A separate agent keeps the read-only guarantee structural.
- For gated control, does the terminal confirmation happen before the bridge
  replies, or does the bridge reply and the terminal confirm asynchronously?
  The first is safer; the second is smoother.
