# Architecture Decision Record (ADR)

## Title

Local judgment backend: an optional self-hosted compute backend for the typed-judgment layer

## Status

Accepted

## Context

ADR 0004 shipped the typed-judgment layer as an opt-in fast-path against a hosted,
paid judgment API. Two constraints of that design are now relaxed deliberately:

- **Billing constraint change.** The typed-judgment layer now supports an optional
  local compute backend alongside the hosted paid API: a judgment model the machine
  owns and runs itself costs no per-call spend, works offline, and keeps state on
  the box. The hosted paid API path remains the default and is byte-identical to
  spec 028 behavior.
- Small open-weight decision models with a wire compatible with the hosted System
  One API are now mature enough to serve single-Choice judgment questions in about
  a hundred milliseconds on consumer GPUs, making the fast-path fast-path even when
  no paid account exists.

The candidate set, the bar, and the measured comparison were produced by the spec 029
hardware spike (spike report `35-spike-report.md`, archived to
`docs/changes/029-local-judgment-backend.md`); its key tables are copied into the
Spike evidence section below so the evidence survives spec archiving. Per ADR 0002
(provider-agnostic general documentation), product and provider names appear in this
record only in the Spike evidence section; everywhere else this decision is called
"the local judgment backend".

## Decision

Add `JUDGMENT_BACKEND` to `scripts/typed-judgment.sh`: valid values `'local' | 'hosted'`;
unset or empty means `hosted` — the default — and every existing spec-028 test passes
unmodified with byte-identical hosted requests.

Backend-switch semantics:

- `hosted` (or unset/empty): unchanged spec-028 contract — `JUDGMENT_API_URL` **and**
  `JUDGMENT_API_KEY` required (missing → fallback, exit 10, no network call);
  `JUDGMENT_MODEL` required for a live call (missing → exit 2).
- `local`: `JUDGMENT_API_URL` required (missing → exit 10, no request — the
  optionality guarantee is preserved identically: nothing configured still means a
  silent immediate fallback); `JUDGMENT_API_KEY` optional — when set, the request
  carries `Authorization: Bearer <key>` exactly as hosted; when unset, the request is
  sent with no Authorization header at all (the winning local recipe serves open by
  default; no dummy header — see the spike report's serving-recipe section);
  `JUDGMENT_MODEL` optional — when unset the script sends the winning backend's
  default alias, defined as a top-of-script constant citing the spike report.
- `JUDGMENT_BACKEND` set to any other value → exit 2 (usage error) with a diagnostic.

Response normalization is untouched: `normalize_output` already tolerates both local
response shapes (verified with mock tests per backend), the bounded retry (max 3,
exponential backoff), the per-day cap, the confidence threshold, diagnostic
truncation, and dry-run mode all behave identically in both modes. A
`scripts/judgment-local-up.sh` companion (`make judgment-up` / `make judgment-down`)
starts, stops, reports, and health-waits the winning recipe with per-process PID
files in the gitignored run directory; confidence thresholds are recalibrated per
backend because the local wire reports confidence on a different scale than the
hosted path's shipped default (see Spike evidence).

`JUDGMENT_MIN_CONFIDENCE=0.28` is the recalibrated threshold recommended for the
local backend — method: 5th percentile (linear interpolation) of correct-answer
confidence on the spike fixture set, floored to two decimals. Hosted mode keeps the
ADR 0004 default; config templates carry the local value commented-out.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Hosted-only (status quo, ADR 0004) | Simplest; zero ops | Per-call spend; mandatory external dependency for the fast-path; state leaves the machine |
| Local backend always-on (auto-detect port) | No config | Violates the optionality guarantee; implicit network behavior; breaks byte-identical hosted path |
| Per-consumer local clients (each prompt files its own server call) | No wrapper | Duplicated retry/cap/secret logic; provider wiring leaks into prompts; untestable |
| Change the normalizer to the local wire's field names | Richer normalized output | Would change the byte-frozen hosted contract mid-spec; the fallbacks (null answer, client-measured latency) are already contract behavior — documented deltas instead |

## Spike evidence

Source: spec 029 spike report (2026-10-09, RTX 5060 Ti 16 GB, sm_120). Winner
Kev-4B (`jaredpalmer/kev-4b`, Apache-2.0 — a single-process local server speaking
the same System One wire the hosted contract describes, `python -m kev.serve`);
runner-up on published evidence: the CLM
vLLM-FP8 recipe (`Contrastive-LM/CLM`, bi-encoder, two-process
`vllm serve` + `clm-serve`).

| Metric (winner Kev-4B) | Value |
|---|---|
| VRAM | 15.6–15.8 GiB used of 16311 MiB (peak 15861 MiB over the call loop) |
| p50 latency: 117 ms | client-measured, 48 calls (server-side: cold-state p50 286 ms, warm ~105 ms, first call 761 ms) |
| accuracy | 24/24 on Coder-authored fixtures (12 ci-triage-style, 12 spec-ux-style); vendor-published new-source accuracy 0.817/0.838 — treat the fixture number as optimistic |
| confidence distribution | correct answers (n=24): min 0.225, p5 0.283, median 0.694, max 0.940; wrong answers: n=0 |
| startup | 11.2 s warm; first run ≈ 50–55 min (anonymous HF rate limit) |
| download | ≈ 8.95 GiB model files in the HF cache (base 8.8 GiB + adapter 153 MB); venv 6.9 GB in the uv cache |
| processes | 1 logical (single PID file, tree-stop) |
| recalibrated threshold | JUDGMENT_MIN_CONFIDENCE=0.28 (5th percentile of correct-answer confidence, floor to 2 decimals); at 0.6 the backend would have discarded 29 % of its correct answers |
| wire compatibility | parses with zero changes beyond the backend switch; per-answer value arrives under `choice` (normalized `answer` is null), `usage`/`latency_ms` are top-level (contract fallbacks), and the literal string-criteria payloads in today's consumer prompts get HTTP 422 → exit-10 fallback (safe) — all enumerated in the spike report |

CLM path A's published figures (never evaluated on this machine — evaluation
stopped at the first bar-meeting candidate): server-side p50 ≈ 28 ms on an RTX 4090
with cached actions; FP8 encoder fits 16 GB; states > 2048 tokens truncated by
default; responses carry `billing_units` per-answer accounting and an
`X-CLM-Latency-Ms` header instead of a body latency.

## Consequences

Easier: the fast-path becomes usable on machines with no paid account, offline
machines, and privacy-sensitive state; per-day cap spend becomes zero for local
mode; the same exit-code contract keeps every consumer's stock procedure intact.

Harder / accepted trade-offs: an optional GPU-resident service becomes part of the
operator surface (start/stop/health/PID/log lifecycle — scripted, not scripted-away);
per-backend threshold calibration is now required (the confidence scales differ);
field-level fidelity on the local wire is degraded to documented null/0/client-
measured fallbacks until a follow-up spec revisits the normalizer contract; consumer
prompt shapes need a follow-up (map-form criteria) before the literal payloads stop
exercising the fallback path. The Verifier's traceability behavior-check, the
deterministic gates, and human approval remain the only authorities — unchanged from
ADR 0004, which this record extends (rather than replaces).

## Compliance

- `scripts/tests/typed-judgment.bats` — backend-switch acceptance scenarios
  AC-029-10 … AC-029-20 (offline fake transport, including both response shapes,
  auth-header presence/absence, fallback, cap, threshold).
- `scripts/tests/judgment-local-up.bats` — recipe lifecycle AC-029-30 … AC-029-38
  (hermetic mock listener; root refusal; PID-tree stop).
- `scripts/tests/typed-judgment-integration.bats` — content contracts for the spike
  report, config templates, this ADR, the docs sections, provider-name scoping
  (AC-029-01/02/21/40-46/50-58/60-66), and cross-artifact threshold consistency
  (report ↔ config ↔ ADR must match).
- `scripts/check-no-hardcoded-secrets.sh` and `scripts/check-model-env.sh` gate the
  config-template changes; the hosted path's 66 spec-028 tests remain green
  unmodified (byte-identical hosted behavior).

## Notes

- 2026-10-09: Decision recorded (spec 029-local-judgment-backend, tasks 1–7). Extends
  ADR 0004; the Coder ran the hardware spike during `/build` per the OQ-029-01
  ruling.
- Key tables above are copies of the spike report measurements; the spike report and
  this ADR are re-checked by the Verifier (`25-verification.md`).
