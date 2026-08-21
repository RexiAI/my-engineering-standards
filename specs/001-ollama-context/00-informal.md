# Informal Spec: Use local ollama qwen3.8:27b for the spec pipeline without losing the thread

## Goal

Run the spec pipeline agents on the local model `ollama/qwen3.8:27b` instead of
cloud models, and make it actually usable — it currently "loses the thread and
forgets" mid-conversation. The primary goal is to use that local LLM on this
machine; a RAG is only acceptable if it turns out to be truly necessary (we do
not believe it is).

## Why it forgets (validated)

- `ollama ps` shows qwen3.8:27b loaded with `context_length: 16384`.
- A systemd override sets `OLLAMA_CONTEXT_LENGTH=16384`
  (`/etc/systemd/system/ollama.service.d/*.conf`).
- The model's native context length is 262144 — we are using ~6% of it.
- The spec pipeline sends large prompts (AGENTS.md ~3.5k tokens, agent defs,
  tool schemas, docs, plus the conversation). These blow past 16k quickly, and
  Ollama silently drops the oldest messages — including, in at least one
  failure mode, the original user query.
- `~/.local/share/opencode/log/opencode.log` records repeated
  `ERROR ... modelID=qwen3.8:27b agent=spec-pipeline
  "AI_APICallError: no user query found in messages"` on 2026-08-16 and
  2026-08-19. This is consistent with truncation dropping the user turn, so the
  provider receives only system/tool messages and errors out.

## Hardware constraints (validated)

- GPU: NVIDIA RTX 5060 Ti, 16 GB VRAM. Model (12.4 GB) + 16k context already
  uses ~15.8/16.3 GB, leaving ~260 MiB free.
- RAM: 45 GB total (~37 GB available) — CPU offload is possible but slower.
- Ollama version 0.32.13 (supports flash attention and KV cache quantization).

## What we want

1. Configure the local model with a context window large enough that a real
   spec-pipeline stage (system prompt + instructions + conversation) fits
   without dropping messages.
2. Prove the fix: no more `no user query found` errors and the model retains
   the thread across turns.
3. If the 27B model at the needed context is too slow for interactive use,
   fall back to a per-stage hybrid: local `ollama/qwen3.8:27b` where prompts
   fit, `opencode-go/deepseek-v4-flash` for oversized stages (noting that the
   opencode-go workspace hit its $25 monthly spending limit on 2026-08-19 and
   the fallback may be unavailable until reset).

## Out of scope (explicit non-goals)

- No RAG, no vector store, no embeddings, no pipeline-architecture changes.
- No change to `opencode.json` agent-model wiring mechanism (the
  `{env:SPEC_*_MODEL}` reference scheme stays).
