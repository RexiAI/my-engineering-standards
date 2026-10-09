# 029 — Local judgment backend (Kev / CLM) for the typed-judgment layer

## Dependency

Builds directly on spec 028 (typed-judgment layer, PR #73, branch
`spec/028-typed-judgment-layer`). If PR #73 is not yet merged when `/build
029` runs, the work stacks on the `spec/028-typed-judgment-layer` branch; if
merged, branch from updated `main`. `scripts/typed-judgment.sh`, ADR 0004, and
the two consumers (`skills/ci-triage/SKILL.md`, `agents/spec-ux.md`) are 028
artifacts and are assumed present.

## Problem

The 028 layer targets a hosted, paid typed-judgment API (provider ids live
only in config per GOVERNANCE no-docs-mirror). No API key is configured on the
target machine, so the fast-path never activates and every classification
falls back to full LLM turns. The user wants a **local, free, open-source
System One backend** on their own hardware so the typed-judgment fast-path
actually runs.

## Candidate backends (research summary — verify in spike, do not trust)

Both speak the same wire protocol as the hosted API (`POST /v1/systemone`
with `{state, model, questions}`; question types `noul`/`choice`/`score`;
answers carry `choice|noul|score`, `probabilities`, `confidence`, `usage`;
Kev additionally returns `latency_ms` and serves a `jev-latest` alias; CLM
adds `billing_units` and a `X-CLM-Latency-Ms` header):

- **Kev** (`github.com/jaredpalmer/kev`, Apache-2.0, Jared Palmer): LoRA
  rank-16 + pointer head over Qwen bases. **Single process**:
  `uv sync --extra serve` then
  `KEV_DTYPE=bf16 uv run --extra serve python -m kev.serve --run
  jaredpalmer/kev-4b --port 8009`. Family: 0.5B (Qwen2.5), 0.6B/8B (Qwen3),
  0.8B/4B/9B (Qwen3.5), 27B (Qwen3.8, 80GB-class). Python 3.12/3.13 + uv.
  NVIDIA supported for larger checkpoints (published walkthroughs are
  Mac-heavy — CUDA behavior must be spike-validated).
- **CLM** (`github.com/Contrastive-LM/CLM`, Apache-2.0; HF
  `Contrastive-LM/CLM-v0.1-8B`): frozen Qwen3-8B encoder + 20M-param
  state/action heads, contrastive InfoNCE training, published Jev-parity
  claims. **Two processes**: vLLM pooling encoder on GPU (:8090,
  `/v1/embeddings`) + `clm-serve` on CPU (:8700, 75MB head, `GET /health`,
  LRU vector cache). Encoder-locked to Qwen3-8B last-token-pooled embeddings.
  Official recipe targets a 24GB GPU at `--max-model-len 2048`; states
  >2048 tokens truncated (raisable with more VRAM). `confidence` = top
  probability minus mean of others (different metric than the hosted API's).

Target machine (verified this session): RTX 5060 Ti **16GB VRAM**
(Blackwell sm_120), 41GB RAM, 12 cores; `uv`, `docker`, `ollama`, Python
3.12 present; no `vllm`/`llama-server` installed. VRAM math: Kev-4B bf16
≈8GB fits; Kev-9B bf16 ≈18GB does not (dtype/offload knobs unproven); CLM
encoder bf16 ≈16GB does not fit — needs FP8 (~8.5GB) or GGUF (~5GB) with
embedding-drift risk against the trained head.

## Solution

### Task 0 — comparative spike (gates everything; produces a written spike report)

Evaluate in this order, stop at the first candidate that meets the bar:

1. **Kev-4B** on CUDA (single process, simplest ops, wire-compatible incl.
   `jev-latest` alias).
2. **Kev-9B / Kev-8B** (quality upside; VRAM-borderline — try dtype/offload
   knobs if the repo exposes them).
3. **CLM path A**: vLLM `Qwen/Qwen3-8B-FP8` pooling encoder + `clm-serve`
   (recent vLLM required for sm_120; validate Blackwell support first).
4. **CLM path B**: `llama-server --embedding --pooling last` with official
   Qwen3-8B GGUF (~5GB) + `clm-serve` (embedding-drift risk vs the trained
   head — must be measured, not assumed).
5. **CLM path C**: CPU encoder (last resort; record latency).

Spike bar (all criteria, measured and recorded in the spike report):
- installs and serves on this machine (CUDA sm_120) without heroic workarounds;
- fits VRAM with headroom (no OOM under repeated calls);
- p50 latency over ≥20 calls on the fixture set (target: seconds-class, i.e.
  still far cheaper than an LLM turn; record actual, no hard cutoff — the
  report recommends);
- **answer quality on known-answer fixtures**: ≥10 real ci-triage-style
  failure states (log excerpt + changed files → expected class among
  flake/regression/infra/config) and ≥10 spec-ux-style applicability states
  (backend-only vs frontend specs → expected run/skip); record accuracy and
  the confidence distribution for correct vs wrong answers;
- wire compatibility: response parses under `scripts/typed-judgment.sh`'s
  existing normalization (fields `choice|noul|score`, `probabilities`,
  `confidence`, `usage`) with **zero script changes** beyond the backend
  switch in Task 1;
- ops simplicity (process count, startup time, model download size).

Winner becomes the documented default recipe; runner-up documented as an
alternative. Spike report is committed as a spec artifact
(`specs/029-local-judgment-backend/35-spike-report.md` or per pipeline
convention) and summarized in the ADR.

### Repo changes (identical whichever backend wins — both speak the wire protocol)

1. **`scripts/typed-judgment.sh` backend switch**: new `JUDGMENT_BACKEND`
   (`local` | `hosted`, default `hosted` — hosted behavior byte-identical to
   028, all 66 existing tests stay green untouched). `local`: requires only
   `JUDGMENT_API_URL` (+ optional `JUDGMENT_MODEL`); `JUDGMENT_API_KEY`
   optional — when absent, send no Authorization header (or a dummy only if
   the spike shows the server requires one). **The 028 optionality guarantee
   is unchanged**: backend unset/unconfigured → silent immediate exit 10;
   server down / 502 / timeout → exit 10 after the existing bounded retries;
   low confidence (< `JUDGMENT_MIN_CONFIDENCE`) → exit 10 with the normalized
   answer still printed (telemetry path preserved).
2. **`scripts/judgment-local-up.sh`** (+ Makefile target): start / stop /
   status / health-wait for the winning recipe (Kev: one uv-run process;
   CLM: encoder + clm-serve). Idempotent; never runs as root; logs to a
   gitignored dir; health endpoint polled with bounded timeout; `up` prints
   the exact `JUDGMENT_*` env lines to add. Model downloads go to the tool's
   own cache (HF/uv defaults), never into the repo.
3. **Confidence recalibration per backend**: from the spike fixtures, compute
   a recommended `JUDGMENT_MIN_CONFIDENCE` default for the winning backend
   (its confidence metric differs from the hosted API's — Kev/CLM thresholds
   must come from measured distributions, not copied 0.6). Document the
   method + numbers in the ADR; ship as the commented default in
   `config/model.local.env.example`.
4. **ADR 0005** (`docs/adr/0005-local-judgment-backend.md`, indexed):
   billing-constraint change (paid hosted API → optional local compute);
   backend-switch semantics; spike results summary; recalibrated threshold;
   provider/product names only via config and ADR evidence (no-docs-mirror
   respected: general docs say "local judgment backend"). Supersedes nothing;
   extends ADR 0004.
5. **Config templates**: `config/model.local.env.example` gains commented
   `JUDGMENT_BACKEND`, local-URL example, recalibrated
   `JUDGMENT_MIN_CONFIDENCE`; `config/agent.local.env.example` notes the key
   is optional for `local`. Real values stay in gitignored per-machine files.
6. **Docs**: amend `docs/SPEC_PIPELINE.md §Typed-judgment layer` and the
   `docs/LOOP_ENGINEERING.md` note with the local-backend mechanism
   (provider-agnostic); OKF `okf/when-to-use-typesafe.md` gains a "Local
   backends" section (Kev/CLM may be named there — scoped operator content)
   + `okf/log.md` entry.
7. **Consumers unchanged**: `skills/ci-triage/SKILL.md` and
   `agents/spec-ux.md` call the script with the same contract — zero edits
   (verify, don't assume: their bats contract tests from 028 must pass
   untouched).
8. **Bats tests** (offline, hermetic, fake-transport pattern from 028):
   backend switch matrix (unset → exit 10; hosted unchanged; local without
   key → no auth header; local with key → header sent), mock local-server
   contract tests for both Kev and CLM response shapes (incl. `latency_ms`,
   `billing_units`, `X-CLM-Latency-Ms` tolerance), health-wait logic,
   down-server fallback, cap behavior unchanged per backend. Plus
   content-contract tests for config templates/docs/ADR presence.
9. **Live E2E (only on a machine with the local stack up; otherwise recorded
   as skipped-with-reason)**: run both consumer question shapes against the
   live local server through `typed-judgment.sh`; record answers, confidence,
   latency, tokens in the run-log telemetry format from 028; compare one real
   case against the LLM fallback path and record agreement/disagreement in
   the spike report addendum (not a gate — advisory).

## Hard requirements (carry-over from 028, non-negotiable)

- **Optionality**: no local stack running + no hosted key → every agent
  behaves exactly as stock (silent exit 10 everywhere).
- **Gate authority**: a judgment never overrides a deterministic gate.
- **Provider-agnosticism**: product names, endpoints, model ids, ports in
  docs only where GOVERNANCE allows (config, ADR evidence, OKF operator
  content) — never in agents/skills/general docs.
- **No secrets committed**; `check-no-hardcoded-secrets.sh` green.
- Existing 66 spec-028 tests green untouched; repo checks green
  (orchestration, gate-consistency, model-env, skills, bats-assertions).

## Out of scope (follow-ups)

- Fine-tuning Kev/CLM heads on our fixtures (both support it; separate spec).
- Phase-2/3 consumers from the 028 roadmap (orchestrator routing, loop-triage,
  pr-review, verifier spot-check, mutation-runner).
- CLM-35B evaluation when released; GGUF quantizations of Kev.
- Serving the local backend to other machines/CI runners (single-machine only;
  CI keeps running stock fallback — no GPU in CI).

## Verification

- Full bats suite + all repo check scripts green locally and in Self CI
  (CI exercises only the offline/hosted-default paths — no GPU there).
- Spike report committed with measured numbers (VRAM, latency, accuracy,
  calibration) — claims in the ADR must match the report.
- Live E2E transcript (or skipped-with-reason) attached to the report.

## Commit policy

No auto-commit. Work lands via the pipeline's PR Opener on
`spec/029-local-judgment-backend` (stacked on `spec/028-typed-judgment-layer`
while PR #73 is open, or on `main` after it merges); merge is human.
