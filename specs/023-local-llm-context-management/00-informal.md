# Local LLM context management for the spec pipeline (research)

Research into why the spec pipeline fails on local LLMs (Ollama) in ways it does
not on cloud providers, and a fix plan. Triggered by a live incident: an Ollama
service restart during a pipeline run produced "no user query found" errors,
then the agent reported it had no memory of the earlier conversation.

## What the incident showed

1. **Service restart wiped pipeline state.** `sudo systemctl restart ollama`
   was run at 19:44:20 (`journalctl` records
   `COMMAND=/usr/bin/systemctl restart ollama` from `TTY=pts/8`). Ollama is
   stateless — it keeps no conversation history server-side.

2. **"No user query found" (HTTP 500).** After the restart the pipeline agent
   called `/v1/chat/completions` six times between 19:53 and 20:07. Ollama
   rejected every one with `routes.go:2684 "no user query found in messages"`.
   That error fires when the request's `messages[]` has no `role:"user"` entry
   — the agent's session lost its state in the restart and sent a malformed
   request.

3. **"Doesn't remember the prior conversation."** At 21:45 the agent *did*
   resend history — 99932 tokens of it. Ollama truncated it:
   `llama_server.go:315 "truncating input prompt" limit=2050 keep=4 new=2050`.
   Default context is 4096 tokens; the model only saw the last 2050 tokens,
   keeping 4. Everything from 3 hours earlier was gone.

## Why local LLMs need this and cloud providers don't

Both Ollama and OpenAI/Anthropic chat APIs are **stateless** — the client must
resend the full `messages[]` on every request. The difference is context window
size:

| | Cloud provider | Local (Ollama) |
|---|---|---|
| Context window | 128K–1M tokens | 4K–32K (default 4096) |
| Full pipeline conversation (99K tokens) | fits | truncated |
| Server-side threads | OpenAI Assistants API has them | none |

So the pipeline does not need *persistence* for local LLMs — it needs
**context management**: sliding window + summarization to fit long
conversations into a small context. Persistence only survives restarts; the
real root cause is 99K tokens being cut to 2K by the model's context limit.

## Full fix plan

1. **Raise Ollama context.** Set `OLLAMA_CONTEXT_LENGTH=32768` in the service
   env (systemd drop-in) or pass `num_ctx` per request. 32K fits the pipeline's
   real conversation needs; 128K would too if VRAM allows.

2. **Context management in the client/pipeline.** Before each request, apply a
   sliding window: keep the system prompt + last N turns verbatim, summarize
   older turns with the same model into a rolling summary. This is what makes
   long pipeline runs fit regardless of provider.

3. **Stateless-safe session handling.** The agent must never assume the server
   remembers anything. On every request it must send a valid `messages[]` with
   at least one `role:"user"` message. The "no user query found" failure mode
   is a client bug — empty or system/assistant-only message arrays must be
   guarded against before the request is made.

4. **Optional durability.** Persist per-agent conversation state to disk
   (`~/.cache/spec-pipeline/conversations/<agent>.jsonl`) so a service restart
   mid-pipeline does not lose the run. This is secondary to (1)+(2); it only
   helps across restarts, not against context truncation.

## Acceptance criteria

- AC-001: pipeline runs end-to-end against Ollama with a 99K-token conversation
  without silent truncation of the working context.
- AC-002: after an Ollama service restart mid-pipeline, the run resumes with
  full history (no "no user query found", no lost prior turns).
- AC-003: every `/v1/chat/completions` request carries a valid `role:"user"`
  message.
- AC-004: context management (sliding window + summarization) documented in
  `docs/SPEC_PIPELINE.md` so the behavior is explicit for local vs cloud.