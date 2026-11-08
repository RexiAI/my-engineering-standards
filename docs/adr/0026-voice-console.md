# 0026 — Voice console: a half-duplex operator surface with a structural never-list

## Status

Accepted

## Context

The operator frequently needs a spoken view of a long-running orchestrator
session: which stage is active, what a gate reported, and what to do next. A
text-only interface forces context switching, and a chat agent that can act on
spoken instructions is a direct route to the actions this repository forbids.

The repo already has two relevant decisions. ADR
[0007](0007-media-agent-family.md) (`docs/adr/0007-media-agent-family.md`)
establishes a media agent family with a user-configured backend contract and no
vendor lock-in. ADR [0011](0011-agent-model-agnostic-gate.md)
(`docs/adr/0011-agent-model-agnostic-gate.md`) requires agent definitions to
stay model-agnostic: no agent pins a `model:` key, and the pipeline's model
assignment has one authoritative source. Both apply to a voice surface: it must
use local, replaceable components, and its agent must not pin a model.

The informal spec asked for three deliverables: a Pocket TTS worker, a bridge,
and a read-only concierge agent. The bridge must be able to capture, transcribe,
speak, and — only when opted in — answer questions and permission requests. The
never-list must be enforced in code, not in prose, because a spoken "yes" is
otherwise indistinguishable from a considered confirmation.

## Decision

1. **A separate, opt-in agent.** The concierge lives at
   `agents-optional/voice-concierge.md`, not in `agents/`. It is `mode: primary`
   with `read: "*": allow` and `edit`/`bash`/`task` all `"*": deny`, so its
   read-only guarantee is structural. It pins no model (ADR 0011).
2. **A bridge with three modes.** `scripts/voice/voice-console.mjs` implements
   `narrate`, `converse`, and opt-in `control`. Every mode can reply, so every
   reply path goes through `scripts/voice/guard.mjs`.
3. **A pure policy classifier.** `scripts/voice/policy.mjs` classifies an
   intent against nine never-list rules and has no I/O side effect. A blocked
   intent throws `PolicyRefusal` and becomes exit 4; no flag overrides it.
4. **Gated control is fail-closed.** Terminal confirmation precedes every
   mutating reply. Declining, EOF, or a confirmation timeout sends nothing.
5. **File modes are first-class.** Capture, recognition, synthesis, playback,
   events, and operator input each have a file-based path. CI needs Node only;
   Python, PyTorch, Pocket TTS, `arecord`, and `ffplay` are optional. Missing
   runtimes are exit 3, never a silent pass.
6. **Weights are never redistributed.** The repository tracks no model weights;
   the cache lives under the gitignored `.cache/`.

## Consequences

- The operator gets a spoken surface without giving a voice path any new write
  authority. A spoken `yes` can answer a read-only question; a mutating action
  still needs a terminal `y`.
- The never-list has one implementation and one test double. A new rule is a
  change to `RULES` and the classifier, not to three modes.
- The bridge can run headless. Every audio path can be exercised with synthetic
  WAVs and a `127.0.0.1` fake server, so the acceptance suite is hermetic.
- Local recognition is the default; a cloud fallback is optional and restricted
  to URL or long audio with a standard key. Audio never leaves the machine by
  default.
- Model quality is the operator's choice. The repository ships no weights and
  no vendor model id; the Hugging Face model-card terms and the voice-cloning
  prohibition travel with whatever the operator fetches.
- Pocket TTS is a runtime dependency for real speech, not a test dependency.
  When it is absent, `--tts-engine silent` keeps every structural check green.
