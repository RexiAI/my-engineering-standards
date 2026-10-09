# 029 — Local judgment backend: hardware spike report (Task 1)

Machine: RTX 5060 Ti 16 GB (16311 MiB, driver 591.86, CUDA target sm_120), 41 GB RAM,
Ubuntu, `uv 0.12.12`, `python 3.13` (via uv), Docker 29.7.2 available but not required.
Run date: 2026-10-09 (UTC). Per OQ-029-01 the Coder ran the spike during `/build` on
this machine; all downloads went to tool caches (HF `~/.cache/huggingface` + xet,
uv `~/.cache/uv`), nothing was placed into the repo tree.

Evaluation order (informal §Task 0, restated in 10-tasks.md): Kev-4B → Kev-9B/8B →
CLM vLLM-FP8 (path A) → CLM llama.cpp-GGUF (path B) → CLM CPU (path C). Stop at the
first candidate that meets the bar.

## Operational bar applied (declared assumption — flagged for the Verifier)

The numeric bar criteria live in `00-informal.md §Task 0`, which the Coder is
information-barred from reading and which `10-tasks.md`/`20-acceptance/` did not
restate. The spike therefore applied this declared operational bar, derived from the
formalized acceptance criteria:

1. installable and serveable on the target machine (16 GB VRAM) with headroom;
2. ≤ 2 processes for the serving recipe; startup within the 120 s health budget;
3. serves ≥ 20 fixture calls with p50 latency in the hundreds-of-ms range or better
   (fast-path utility: must be cheaper in wall-clock than the full-LLM procedure);
4. answers the ci-triage-style and spec-ux-style Choice questions with correct labels
   on a clear majority of the fixture set (must beat the 25%/33% chance floor with
   margin);
5. `scripts/typed-judgment.sh` parses the response structurally (exit-code contract
   holds) with zero changes beyond the Task 2 backend switch; field-level deltas are
   enumerated rather than silently absorbed.

**Deviation note for the record:** if the informal §Task 0 numbers differ from this
bar, the Verifier/Architect should re-adjudicate the winner from the measured tables
below — every bar criterion's measurement is recorded here, so re-deciding is a
reading task, not a re-run.

## Candidate results

### Kev-4B — EVALUATED — bar: MET (winner)

Model: `jaredpalmer/kev-4b` (Kev 1.0 family, adapter on `Qwen/Qwen3.5-4B-Base`,
Apache-2.0, temperature 2.41 shipped calibrated). Repo: github.com/jaredpalmer/kev.

Install steps actually executed:

```bash
git clone --depth 1 https://github.com/jaredpalmer/kev.git   # into /tmp scratch, then ~/.local/share/judgment-local/kev per recipe default
cd kev && uv sync --extra serve                               # py3.13 via .python-version; torch 2.8.0+cu128; venv 6.9 GB
uv run --extra serve python -m kev.serve --run jaredpalmer/kev-4b --port 8009
```

sm_120 note: default torch wheels (2.8.0+cu128) support Blackwell consumer — verified
`torch.cuda.get_device_capability() == (12, 0)` before serving. `flash-linear-attention`
(fused Qwen3.5 kernels) was NOT installed; the server runs correct-but-unfused
(prints "fused Qwen3.5 kernels off" at startup). Optional speedup, not required.

| Measurement | Value |
|---|---|
| VRAM usage | 15.6–15.8 GiB used on the 16311 MiB card (peak 15861 MiB sampled at 4 Hz over the 48-call loop; ~450 MiB headroom; weights bf16 + CUDA-graph buffers + 4-state prefix cache). Fits, tight. OOM-retry path (cache drop + re-run) exists in the server. |
| p50 latency: 117 ms | client-measured over 48 calls (24 cold + 24 warm, ≥ 20 required; one Choice question per call). Cold-state server model time p50 286 ms; warm p50 ~105 ms; first-ever call 761 ms; isolated single-call probes via typed-judgment.sh 397–565 ms client / 66–176 ms server. |
| ci-triage accuracy | 12 / 12 = 1.00 (labels on first-seen cold calls; warm re-pass 12/12 again) |
| spec-ux accuracy | 12 / 12 = 1.00 (same protocol) |
| confidence distribution | correct answers (n=24): min 0.225, p5 0.283, p10 0.335, median 0.694, max 0.940; buckets [0.2,0.4): 3, [0.4,0.6): 5, [0.6,0.8): 12, [0.8,1.0]: 4. wrong answers: n = 0 (distribution empty) |
| process count | 1 logical process (OS tree: `uv run` launcher + python child — single PID file, tree-kill on stop; see Recipe ops) |
| startup time | 11.2 s warm (weights cached; measured through `scripts/judgment-local-up.sh up` within its default 120 s health budget). Cold first run ≈ 50–55 min, dominated by the anonymous HF download (~3 MB/s rate limit; a `HF_TOKEN` fixes this). |
| model download size | 8.8 GiB (`Qwen/Qwen3.5-4B-Base`) + 153 MB (`jaredpalmer/kev-4b` adapter repo, includes checksums/cards) ≈ 8.95 GiB total in the HF cache; uv venv 6.9 GB in the uv cache. Nothing in the repo tree. |

Fixture provenance: the 24 fixtures are Coder-authored synthetic cases mirroring the
two consumer question shapes (`skills/ci-triage/SKILL.md` Decision-guide rubrics;
`agents/spec-ux.md` applicability rubrics), stored outside the repo
(`/tmp/opencode/kev-spike/fixtures.jsonl`). 100 % accuracy on Coder-authored fixtures
is an optimistic ceiling, not a published claim; Kev-4B's vendor-published new-source
accuracy is 0.817/0.838 (dev/test), which is the realistic planning figure.

### Kev-9B/8B — NOT EVALUATED

**Skip reason:** stopped at first candidate meeting the bar (Kev-4B, per OQ-029-01
bounded procedure); also the vendor-published ~17 GB VRAM requirement exceeds this
16 GB card, so it would likely fail criterion 1 anyway.

### CLM vLLM-FP8 (path A) — NOT EVALUATED

**Skip reason:** stopped at first candidate meeting the bar (Kev-4B, per OQ-029-01 bounded procedure).

### CLM llama.cpp-GGUF (path B) — NOT EVALUATED

**Skip reason:** stopped at first candidate meeting the bar (Kev-4B, per OQ-029-01 bounded procedure).

### CLM CPU (path C) — NOT EVALUATED

**Skip reason:** stopped at first candidate meeting the bar (Kev-4B; path C exists only as a no-GPU fallback, and a CUDA GPU was visible, so per the OQ-029-01 ruling it was never in scope).

## Winner and runner-up

Winner: Kev-4B — first candidate in evaluation order; met every operational bar
criterion with measured evidence: fits the 16 GB card, one-process recipe, 11.2 s
startup, p50 latency: 117 ms, 24/24 fixture accuracy (published 0.82–0.84 realistic),
TypeSafe-compatible wire. Rationale: cheapest ops surface (single process, single
binary entry point), smallest download among GPU-viable candidates, warm latency well
below the full-LLM procedure it accelerates, and calibrated confidences that support
threshold recalibration.

Runner-up: CLM vLLM-FP8 (path A) — named on published evidence without evaluation
(evaluation stopped at the winner). Rationale: the bi-encoder architecture reports
server-side p50 ≈ 28 ms on an RTX 4090 for cached action sets and Qwen3-8B FP8 fits
16 GB; it is the strongest published latency figure of the unevaluated candidates.
Costs: two-process recipe (vLLM pooling encoder + `clm-serve`), states > 2048 tokens
truncated by default, and no published ci-triage/spec-ux-style accuracy. If the
informal §Task 0 bar had required sub-100 ms p50, this is the candidate that would
have won instead.

## Recommended confidence threshold

Method: 5th percentile (linear interpolation) of correct-answer confidence measured
on the spike fixture set (24 cold single-Choice calls), floored to two decimals.

Measured p5 of correct answers = 0.2831 →
Recommended value: 0.28

Rationale: Kev reports Choice confidence as `(p_max − 1/K)/(1 − 1/K)` — a different
scale than the hosted path's shipped default. At the old 0.6 the local backend would
have discarded 7 of 24 correct answers (29 % needless fallbacks); at 0.28, 23 of 24
correct answers stay usable and every usable answer was correct (the one sub-threshold
case was the genuinely-ambiguous ux-11 at 0.225, which the wrapper then routes to
fallback — exactly the behavior the contract intends). Wrong-answer distribution was
empty (0 wrong answers), so no separation evidence — treat 0.28 as a floor calibrated
on correct answers only; tighten if production error rates appear (spike note, mirrors
the vendor "check a threshold on your own data" guidance).

## Serving recipe (parameterizes Tasks 3 and 4)

- Exact serving command: `cd <clone-dir> && uv run --extra serve python -m kev.serve --run jaredpalmer/kev-4b --port 8009`
- Port: `8009`
- Health endpoint path: `/v1/models` (GET — no `/health` route exists; 200 = loaded)
- API endpoint path: `/v1/systemone` (POST)
- Model identifier: `jaredpalmer/kev-4b` (Kev 1.0, weights revision `139fdd94`)
- Default model alias sent when `JUDGMENT_MODEL` unset: `kev-latest` (OQ-029-03; the
  server also accepts `jev-latest`)
- Process count: 1 (one logical server process; OS tree is 2: uv launcher + python
  child — tracked via a single `kev.pid`, stopped via tree-kill)
- Auth: server is open by default; `Authorization: Bearer <key>` is required only when
  `KEV_API_KEY` is set. Local mode therefore sends **no** Authorization header when
  `JUDGMENT_API_KEY` is unset (Task 2 AC-029-12; no dummy header needed — this
  document is the authority).
- PID file per OQ-029-04: single `kev.pid` in `.cache/judgment/` (+ `kev.log`).

## Recipe ops notes

- `uv run` does not exec its python child (launcher + child); the up/down script kills
  the process tree (parent then children) — verified: after `down`, port free, GPU
  back to the 1243 MiB display baseline, zero `kev.serve` processes.
- Health probe budget: the script keeps the Task-3 default of 120 s; measured warm
  startup is 11.2 s. Set `JUDGMENT_LOCAL_TIMEOUT_SECONDS` if weights must also
  download on first run.
- Anonymous HF downloads are rate-limited (~3 MB/s); set `HF_TOKEN` for first-run
  speed. Downloads land in `~/.cache/huggingface` (hub + xet) only.
- Useful server env knobs: `KEV_API_KEY` (require bearer), `KEV_DTYPE=fp32` (exact
  eval path, more VRAM), `KEV_DATE_FACTS=1`, `KEV_TRUNCATE_STATES=1`,
  `KEV_PREFIX_CACHE` (state cache size).
- Wire: responses carry top-level `usage` and `latency_ms`; per-answer `type/choice/
  confidence/probabilities`; every response has `x-typesafe-request-id`.

## Wire compatibility

Measured against the live server (raw response captured at 2026-10-09T17:31:16Z, in
the E2E addendum below): `scripts/typed-judgment.sh` parses the winner's response with
zero changes beyond the Task 2 backend switch — the exit-code contract holds
(HTTP 200 → `response_valid` passes on the numeric per-answer `confidence`, the
`normalize_output` jq runs unchanged, exit 0 for usable confidences, exit 10 for
low-confidence with the answer still printed). `normalize_output` needed no
modification; mock tests for both spec-029 shapes pass (AC-029-16/17).

Enumerated fidelity deltas (documented, not silently absorbed — these are exactly the
kind AC-029-05 asks the report to list):

1. The winner returns the selected option under per-answer `choice`, not `answer`.
   The wrapper's normalized `answer` is therefore `null` on a real Kev wire, while
   `probabilities` carries the full distribution (argmax = the answer). The hosted
   028 contract's `answer` key is an idealization the real TypeSafe wire also does not
   emit (published API reference uses `choice`/`noul`/`score` per answer too).
   Follow-up needed for a `choice→answer` alias in `normalize_output` — out of scope
   for spec 029 (it would change the byte-frozen hosted path). Consumers today read
   `probabilities`; the E2E addendum records both views.
2. `usage` and `latency_ms` are top-level on the wire; the wrapper's per-answer
   lookups yield `usage: 0` and client-measured `latency_ms` (both are the 028
   contract's documented fallbacks — behavior, not breakage).
3. Request side: the Kev server validates `criteria` as an option→description map
   (identical to the TypeSafe API contract). The literal question JSON embedded in
   the two consumer prompts today uses a **string** `criteria` plus `options` — the
   live server rejects it with 422 → the wrapper exhausts its 3 attempts → exit 10 →
   consumers run their stock procedure (safe fallback, measured in E2E). Consumer
   prompt shapes should move to map-criteria in a follow-up spec; not changed here
   (AC-029-74 forbids touching consumer files).

## E2E addendum

E2E-RAN — local server live on this machine (Kev-4B via `scripts/judgment-local-up.sh up`,
torn down after capture; GPU freed). Both consumer question shapes ran through
`scripts/typed-judgment.sh` with `JUDGMENT_BACKEND=local` (no key, no model env set —
default alias sent), spec-028 telemetry format, timestamps UTC.

Normalized-view telemetry (exactly what a consumer sees on stdout):

{"judgment":"classification","question_shape":"ci-triage","backend":"local","answer":null,"confidence":0.7881,"latency_ms":397,"usage":0,"exit":0,"timestamp":"2026-10-09T17:31:16Z"}
{"judgment":"applicability","question_shape":"spec-ux","backend":"local","answer":null,"confidence":0.797,"latency_ms":565,"usage":0,"exit":0,"timestamp":"2026-10-09T17:31:16Z"}

Raw-server view (same two questions, wire fields — the `answer: null` above is
delivered as `choice` here): ci-triage → `choice":"flake","confidence":0.7881,"usage":{"input_tokens":176,"output_tokens":75},"latency_ms":66.2`; spec-ux → `choice":"run","confidence":0.797,"usage":{"input_tokens":139,"output_tokens":61},"latency_ms":176.2`. (Raw captures at 2026-10-09T17:27:18Z / 17:33Z.)

Fallback-path probe (literal consumer payload, string criteria): exit 10 after 3
attempts (HTTP 422 from request validation), timestamp 2026-10-09T17:31:17Z —
consumer stock procedure would run unchanged; no crash, no key, no leak.

LLM-fallback comparison (advisory): for the ci-triage case (same-signature flake,
recorded in the quarantine ledger, identical-commit rerun passed), the local backend's
answer was `flake` (confidence 0.7881); the stock LLM procedure's answer for the same
state is also `flake` (prior-state + retry-pass rubric branch). **agreement** — the
typed answer matched the fallback classification. Recorded as advisory, not a gate
(ADR 0004 unchanged: the deterministic path remains authoritative).

Daily-cap interaction: E2E used a scratch `JUDGMENT_CAP_DIR` (cap unset → no counter
written), so the machine's real per-day counter is untouched.

## Cross-artifact note (OQ-029-02 requirement)

The key results tables (VRAM, p50 latency, accuracy, calibration/confidence
distribution) are copied into ADR 0005 (`docs/adr/0005-local-judgment-backend.md`
§Spike evidence) and must also be re-recorded by the Verifier in
`25-verification.md`, so the evidence survives `specs/029-*` archiving. The
`typed-judgment.sh` `DEFAULT_LOCAL_MODEL` constant and `judgment-local-up.sh` recipe
parameters cite this report.
