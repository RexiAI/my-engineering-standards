# Task list — 001-ollama-context

Local `ollama/qwen3.8:27b` for the spec pipeline without losing the thread.

## Context the Coder must know

- **Tier**: `mvp` (no `AGENTS_<PROJECT>.md` at repo root; `check-code-principles.sh` auto-detects `tier: mvp`). Mutation testing and property tests are skipped. Pipeline runs Specifier → Coder → Refactorer → Verifier → PR Opener.
- **Non-goals** (from `00-informal.md`): no RAG / vector store / embeddings; no pipeline-architecture change; no change to the `opencode.json` `{env:SPEC_*_MODEL}` wiring mechanism. The model-env mechanism (`config/model.local.env` + `.envrc` dotenv chain) is used as-is.
- **Machine state is part of the deliverable**: the systemd override lives at `/etc/systemd/system/ollama.service.d/` (outside the repo, needs sudo) and `config/model.local.env` is gitignored. The committed PR surface is the harness, the override *template*, and the check/validation scripts. The Coder must perform the live machine steps and verify against the live system (AGENTS.md — a diff that compiles and a diff that works are different claims).
- **Verified current state** (2026-08-19): `ollama ps` shows `qwen3.8:27b` with `CONTEXT 16384`, 33%/67% CPU/GPU, 18 GB total. Native model context 262144. Ollama 0.32.13 (flash attention + KV cache quantization supported). Existing overrides: `context.conf` (`OLLAMA_CONTEXT_LENGTH=16384`), `keepalive.conf` (`OLLAMA_KEEP_ALIVE=24h` — **out of scope, leave untouched**). `~/.local/share/opencode/log/opencode.log` records repeated `AI_APICallError: no user query found in messages` for `modelID=qwen3.8:27b agent=spec-pipeline` on 2026-08-16 and 2026-08-19.
- **Why benchmark-first is sound**: the harness sets `num_ctx` per request via the API (`options.num_ctx`), which works independently of the server's `OLLAMA_CONTEXT_LENGTH` default (that default is what the opencode client relies on). Task 1 therefore measures all four values against the server as-is. The selection uses the pre-flash-attention, pre-q8_0 baseline, which is **conservative**: flash attention + q8_0 KV cache only *reduce* KV VRAM, so any context that fits the baseline also fits the target configuration. Task 2's post-restart re-probe at the selected context is the definitive confirmation.
- **Repo test surface**: shell selftests (`scripts/*.selftest.sh`) citing `AC-NNN-NN` IDs — that is what `scripts/check-scenario-traceability.sh` greps for, and the Verifier re-runs the suite. Every new script must also keep the design-principles gate green (no FAIL from `scripts/check-code-principles.sh`).

## Execution order and dependencies

1. **Task 1** (benchmark harness) — must run to a complete report before Task 2.
2. **Task 2** (systemd override) — reads Task 1's selected value; applies + restarts + re-probes.
3. **Task 3** (e2e validation) — requires Task 2 applied (new server env).
4. **Task 4** (hybrid fallback wiring) — consumes Task 3's decision line.

## Open questions (human must resolve before `/build`)

1. **Tokens/sec floor for "too slow for interactive use"** — `00-informal.md` never quantifies it. Default: `--min-tok-s 15` (15 tok/s). Confirm or adjust; the value is a flag, so the benchmark can be re-run with a different threshold without code changes.
2. **VRAM headroom floor** — `00-informal.md` cites ~260 MiB free at 16k as the problem. Default: keep ≥ 0.3 GiB free (`size_vram ≤ 16.0 GiB` of the 16.3 GiB total, `--vram-headroom-gib 0.3`). Confirm or adjust.
3. **Representative stage for the e2e run** — default `spec-specifier` (first stage, prompt-heavy; its agent file ships with this repo). Confirm, or substitute another stage (e.g. `spec-pipeline`).
4. **selected=NONE behavior** — if the report selects no viable context, the pipeline does NOT stop: Task 2 keeps `OLLAMA_CONTEXT_LENGTH=16384`, and Task 4 maps every stage to the cloud fallback. Confirm this is desired rather than halting for a human decision.

---

## Task 1 — Empirical context benchmark harness

`scripts/benchmark-ollama-context.sh` (+ `scripts/benchmark-ollama-context.selftest.sh`): measures `qwen3.8:27b` at `num_ctx` 16384 / 32768 / 49152 / 65536 with a synthetic long-prompt + follow-up thread-retention probe, recording `size_vram`, tokens/sec, and probe pass/fail per value. Produces the CSV report whose summary row is the machine-readable input to Task 2.

**Dependencies**: none (runs against the server as-is; per-request `num_ctx`). **Scenarios**: `20-acceptance/AC-001-benchmark-harness.md` (`AC-001-01`…`AC-001-09`).

### Acceptance criteria

- `scripts/benchmark-ollama-context.sh` exists, is executable, and passes `bash -n`.
- Default sweep is the four values 16384, 32768, 49152, 65536; `--num-ctx` overrides the list.
- `--out <file>` is required; running with `--out <file>` produces `<file>` as CSV: one header row, one data row per measured value, plus a final summary line, and exits 0.
- Each data row records exactly: `num_ctx`, `size_vram_gib` (from the ollama `/api/ps` `size_vram` for the loaded model, converted to GiB), `tokens_per_sec` (`eval_count`/`eval_duration` from the `/api/generate` response), `prompt_tokens` (`prompt_eval_count`), `context_loaded` (actual loaded context from the response), `probe_result` (`PASS` | `FAIL` | `INVALID`).
- Thread-retention probe: turn 1 is a synthetic user message whose first 64 tokens embed a unique marker token; turn 2 is a follow-up asking for that marker. `probe_result` is `PASS` iff the turn-2 completion contains the marker, `FAIL` iff it does not (simulates the observed truncation failure mode: the oldest message — and its marker — is dropped).
- A row is `INVALID` (excluded from selection) when `prompt_tokens < 0.8 × num_ctx` (under-filled probe — vacuous) or when `context_loaded ≠ num_ctx` (requested context not honored).
- The summary line records the selected context: the largest `num_ctx` among rows with `probe_result=PASS`, `size_vram_gib ≤ 16.3 − <headroom>`, and `tokens_per_sec ≥ <min>`. When no row qualifies, the summary records `selected=NONE` and the script still exits 0.
- `--min-tok-s` defaults to 15; `--vram-headroom-gib` defaults to 0.3 (see Open questions 1–2).
- `--probe-only <num_ctx>` runs a single probe at that context: exit 0 on `PASS`, 1 on `FAIL` (used by Task 2's post-restart re-probe).
- The report header records the server environment measured under (ollama version, flash attention on/off, KV cache type, model id) so the numbers are interpretable as baseline vs target config.
- Exit 2 (tooling failure, repo `check-common.sh` convention) when: `--out` missing, ollama unreachable, or the model is not found.
- `scripts/benchmark-ollama-context.selftest.sh` exists, exits 0, cites every `AC-001-xx` ID in test names, and uses mocked ollama API responses (no live server in CI).
- The script produces no FAIL from `scripts/check-code-principles.sh`.

---

## Task 2 — Systemd ollama service override (flash attention + KV cache + selected context)

Replaces `/etc/systemd/system/ollama.service.d/context.conf` with a three-variable override, ships the source-of-truth template in the repo, applies it via `systemctl daemon-reload` + `systemctl restart ollama`, and verifies. The `OLLAMA_CONTEXT_LENGTH` value is the summary `selected` value from Task 1's report — this is the whole point of the change (16384 → the empirically viable maximum).

**Dependencies**: Task 1 report. **Scenarios**: `20-acceptance/AC-002-systemd-override.md` (`AC-002-01`…`AC-002-07`).

### Acceptance criteria

- `templates/ollama.service.d/context.conf` exists with exactly three `Environment=` lines:
  `OLLAMA_CONTEXT_LENGTH=<selected>`, `OLLAMA_FLASH_ATTENTION=1`, `OLLAMA_KV_CACHE_TYPE=q8_0`,
  where `<selected>` is the summary value from the Task 1 report (never invented; read from the report). A template header comment explains the provenance of the value.
- `/etc/systemd/system/ollama.service.d/context.conf` is byte-identical to the template (`cmp` exits 0) after apply.
- `systemctl daemon-reload` and `systemctl restart ollama` were executed; `systemctl show ollama.service -p Environment` contains all three variables with the template values.
- `ollama ps` reports `qwen3.8:27b` with `CONTEXT = <selected>`.
- The Task 1 probe re-run at the selected context under the new server env (`benchmark-ollama-context.sh --probe-only <selected>`) exits 0 — the definitive proof that the chosen context fits with flash attention + q8_0.
- `scripts/check-ollama-override.sh` exists and bundles the verification: exit 0 when template == applied file AND `systemctl show` carries the three vars AND `ollama ps` shows the selected context; exit 1 on any divergence (with the differing variable named); exit 2 when required tools (`cmp`, `systemctl`, `ollama`) are missing.
- `scripts/check-ollama-override.selftest.sh` exists, exits 0, cites every `AC-002-xx` ID, and mocks `cmp`/`systemctl`/`ollama` (no sudo in CI).
- When the Task 1 summary says `selected=NONE`: the apply step is skipped, `check-ollama-override.sh` reports SKIP (exit 0), the live override retains `OLLAMA_CONTEXT_LENGTH=16384`, and Task 4's cloud-fallback path covers all stages.
- `keepalive.conf` (`OLLAMA_KEEP_ALIVE=24h`) is untouched.
- No FAIL from `scripts/check-code-principles.sh`.

---

## Task 3 — End-to-end validation on the local model

`scripts/validate-ollama-e2e.sh` (+ selftest): runs a real spec-pipeline stage agent against `ollama/qwen3.8:27b` in a multi-turn session, then proves the fix from the evidence in `00-informal.md`: no `no user query found` errors and the thread retained across turns. Emits the machine-readable per-stage decision line that Task 4 consumes.

**Dependencies**: Task 2 applied. **Scenarios**: `20-acceptance/AC-003-e2e-validation.md` (`AC-003-01`…`AC-003-06`).

### Acceptance criteria

- `scripts/validate-ollama-e2e.sh` exists and is executable; `bash -n` passes.
- It invokes `opencode run` targeting the representative stage agent (default `spec-specifier`, see Open question 3) with `SPEC_SPECIFIER_MODEL=ollama/qwen3.8:27b` exported for the run — a real stage invocation on the local model, not a mock.
- The run is two turns: turn 1 embeds a unique marker token in the task prompt; turn 2 is a follow-up that references turn-1 content and asks for the marker.
- After the run it records the log offset before the run and greps the log slice `[run start, now]` in `~/.local/share/opencode/log/opencode.log` for `no user query found` attributed to the run (`modelID=qwen3.8:27b`): exit 1 if any occurrence is found in the slice, 0 if none.
- Thread retention: the turn-2 final answer must contain the turn-1 marker — exit 1 if absent.
- It emits a machine-readable decision to stdout and to `--out <file>`: `LOCAL_STAGES=<space-separated agent ids>` and `CLOUD_FALLBACK_STAGES=<space-separated agent ids>`. Default: all eight stage agents (`spec-specifier spec-ux spec-verifier spec-mutation-runner spec-pr-opener spec-coder spec-refactorer spec-pipeline`) are `LOCAL`; a stage is recorded in `CLOUD_FALLBACK_STAGES` only when the run's evidence shows it fails (non-zero exit, a `no user query found` error in its log slice, or a context-overflow error in its session).
- Exit 2 when `opencode` is unavailable or the log path is unreadable.
- `scripts/validate-ollama-e2e.selftest.sh` exists, exits 0, cites every `AC-003-xx` ID, and mocks the opencode invocation and the log (no live model in CI).
- No FAIL from `scripts/check-code-principles.sh`.

---

## Task 4 — Per-stage hybrid fallback wiring in `config/model.local.env`

Wires the Task 3 decision into the existing per-machine model mechanism: local `ollama/qwen3.8:27b` where prompts fit, `opencode-go/deepseek-v4-flash` for stages the e2e evidence flags. The mechanism (`{env:SPEC_*_MODEL}` in `opencode.json` + `.envrc` dotenv chain) is used as-is — this task only edits the gitignored per-machine override file and adds a verification script.

**Dependencies**: Task 3 decision line. **Scenarios**: `20-acceptance/AC-004-hybrid-fallback.md` (`AC-004-01`…`AC-004-06`).

### Acceptance criteria

- `config/model.local.env` (gitignored) is updated per the Task 3 decision: every stage in `LOCAL_STAGES` → `ollama/qwen3.8:27b`; every stage in `CLOUD_FALLBACK_STAGES` → `opencode-go/deepseek-v4-flash`. The existing commented-intent lines are replaced by the actual values.
- Exactly the eight `SPEC_*_MODEL` variables are set; no stage resolves to any other value; the eight agent names in `opencode.json` all appear.
- The file header documents: (a) the wiring mechanism is unchanged (`opencode.json` still resolves `agent.*.model` from `{env:SPEC_*_MODEL}`); (b) opencode reads config once at startup, so a restart is required for the change to take effect; (c) the `opencode-go` fallback may be unavailable until the monthly $25 spend limit resets (observed 2026-08-19) — local stages keep working regardless.
- `scripts/check-ollama-hybrid-wiring.sh` exists: parses `config/model.local.env` and the Task 3 decision file, exits 0 when every stage's value matches the mapping, 1 on any mismatch (naming the stage), 2 when the decision file or `config/model.local.env` is missing/unreadable.
- Live resolution verification (performed by the Coder, recorded as evidence): after restart, `opencode debug config` resolves each LOCAL stage's `agent.<name>.model` to `ollama/qwen3.8:27b` and each CLOUD stage to `opencode-go/deepseek-v4-flash`. The verification commands and their output are recorded (the 25-verification.md evidence-block style applies).
- `scripts/check-ollama-hybrid-wiring.selftest.sh` exists, exits 0, cites every `AC-004-xx` ID, and mocks the env-file and decision-file parsing (no live direnv/openccode in CI).
- No FAIL from `scripts/check-code-principles.sh`.
