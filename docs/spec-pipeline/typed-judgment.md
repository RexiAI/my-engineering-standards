# Typed-judgment layer (shared)

Shared reference. Read it from the stage file that names it; the index is
`docs/SPEC_PIPELINE.md`.

## Typed-judgment layer

Some pipeline steps make small probabilistic classification calls (CI failure
class, spec-ux applicability) that a typed-judgment API answers cheaply: send
state + a typed question, get back an answer with a confidence. The pipeline
supports this as an **opt-in** fast-path — see ADR 0004.

- **Mechanism.** `scripts/typed-judgment.sh` is a curl+jq wrapper configured
  entirely through the gitignored per-machine env files (the commented
  `JUDGMENT_*` entries in `config/model.local.env.example` and
  `config/agent.local.env.example`). Unset credentials mean no network call:
  the script immediately falls back. It enforces a bounded retry (max 3
  attempts with exponential backoff), a per-day call cap
  (`.cache/judgment-cap-YYYY-MM-DD`, gitignored), a confidence threshold
  (default `0.6`), and never prints the API key or an untruncated state
  payload in diagnostics. `--dry-run` prints the request body offline. The
  contract the wrapper and its two probe consumers share — the reason-line
  format, the bounded-probe call shape, the payload-cap default, and the
  synthetic fitness question — lives in `scripts/judgment-lib.sh`, sourced by
  all three scripts.
- **Local backend option.** `JUDGMENT_BACKEND=local` activates a local compute
  backend (spec 029, ADR 0005): a judgment model you serve on your own
  machine instead of a hosted paid API. In local mode the API key is optional
  (requests go without an `Authorization` header when no key is configured)
  and the model id is optional (unset sends the backend's default alias). The
  default backend is `hosted` — unset or empty behaves exactly as before —
  and the optionality guarantee is unchanged in both modes: nothing
  configured means no call and an immediate fallback (exit `10`). The
  mechanism stays provider-agnostic here; the concrete backends and the
  serving recipe live in the ADR evidence section and the config templates.
  `scripts/judgment-local-up.sh` starts and stops the local backend; `make
  judgment-up` / `make judgment-down` wire the same script.
- **Exit-code contract.** `0` = usable answer (parsed, every question
  answered, every confidence at or above the threshold); `10` = fallback
  (no fast-path exists: not configured, cap exceeded, transport/HTTP failure
  after retries, unparsable response, or low confidence); `2` = usage error.
  Exit `10` is load-bearing and means exactly one thing: **no fast-path
  exists → run the original (stock) procedure**. `BLOCKED` or halting is
  never a valid consumer response to exit `10`; exit `10` never halts a
  consumer. The only consumer outcome that halts is a genuine ambiguous
  answer at exit `0`.
- **Fallback reasons.** Every exit `10` writes one
  `typed-judgment: reason=<word>` line to stderr, with `<word>` one of
  `unconfigured` (credentials absent), `unreachable` (transport/HTTP failure
  after retries), `payload_overflow` (the state was capped and truncated —
  emitted while the call still proceeds, so a usable answer keeps exit `0`),
  or `error` (daily cap, unparsable response, confidence below threshold).
  The line is not debug-gated and never carries the key or state content.
- **Fail-open preflight.** `scripts/judgment-preflight.sh` is a bounded
  fitness probe run as the first action of `/spec` and `/build`. It is silent
  when the local backend is not configured; when configured it makes one
  Choice probe through `scripts/typed-judgment.sh` (timeout 5 s, no backoff,
  confidence threshold 0 for the probe — it measures reachability and
  inference, not the calibration of one synthetic question) and caches the
  outcome in `${JUDGMENT_CAP_DIR:-.cache}/judgment-preflight`
  for `JUDGMENT_PREFLIGHT_TTL_SECONDS` (default 300). A failed probe prints
  one warning naming `make judgment-up` and `continuing without` the
  fast-path, then exits `0`: it never blocks a stage by default.
  `--require-judgment` or `JUDGMENT_REQUIRED=1` opts into a hard failure.
- **Payload cap.** The wrapper caps the serialized state at
  `--max-state-bytes` / `JUDGMENT_MAX_STATE_BYTES` (default 12 KB = 12,288
  bytes; the flag wins). An over-cap state is truncated deterministically to
  head + marker + tail, where the marker names the omitted byte count and
  the result is at most the cap. Truncation is a degradation, not a
  fallback: the truncated payload is sent, `payload_overflow` is recorded,
  and a usable answer still exits `0`. This prevents the observed local
  backend crash on oversized payloads (measured first failure at 20,548
  bytes on 2026-10-26, drifting lower after a failing request — 12 KB keeps a
  wide margin).
- **Operator surface.** `make judgment-status` runs
  `scripts/judgment-status.sh`, which reports liveness (the same PID-file
  signal as `scripts/judgment-local-up.sh status`) and payload fitness (a
  small probe plus a max-size probe at the cap). It exits `0` only when the
  backend is running and both probes pass.
- **Consumers must preserve their stock procedure.** Every consumer of the
  fast-path keeps its original LLM/manual procedure intact and runs it on
  any exit `10` — the typed judgment may only pick a path the consumer
  already knew how to take, and never overrides a deterministic gate or a
  human. A consumer with no fallback must not adopt the layer.
