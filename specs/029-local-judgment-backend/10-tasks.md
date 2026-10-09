# 029 — Local judgment backend: Tasks

Dependency: spec 028 (typed-judgment layer, PR #73 / branch `spec/028-typed-judgment-layer`). `scripts/typed-judgment.sh` and its 66 bats tests are present in the working tree. If PR #73 is not merged when `/build 029` runs, stack on `spec/028-typed-judgment-layer`; if merged, branch from updated `main`.

## Task 1 — Comparative hardware spike and report

Evaluate candidate local judgment backends on the target machine (RTX 5060 Ti 16GB, Blackwell sm_120, 41GB RAM) in the priority order defined in `00-informal.md §Task 0`. Stop at the first candidate that meets the bar. Produce a written spike report.

**Acceptance criteria:**

- Spike report committed at `specs/029-local-judgment-backend/35-spike-report.md`.
- Report records, for each candidate evaluated before the winner (and the winner itself): install steps actually executed, VRAM usage under repeated calls, p50 latency over ≥20 calls on the fixture set, accuracy on ≥10 ci-triage-style fixtures and ≥10 spec-ux-style fixtures, confidence distribution for correct vs wrong answers, process count, startup time, model download size.
- Report declares a winner and a runner-up with rationale.
- Report records the recommended `JUDGMENT_MIN_CONFIDENCE` value for the winning backend, computed from the measured confidence distribution (method stated: e.g. 5th-percentile of correct answers, or stated alternative).
- Report records the exact serving command, port, model identifier, and process count for the winning recipe — these values parameterize Tasks 3 and 4.
- Report records wire-compatibility result: `scripts/typed-judgment.sh` parses the winner's response with zero changes beyond the Task 2 backend switch.
- For each candidate that was not evaluated (skipped after the winner): a one-line skip reason.

**Resolved (pre-/build, human + architect rulings):**

- OQ-029-01 RESOLVED — the **Coder runs the spike during `/build`** on this machine (RTX 5060 Ti, CUDA sm_120 present; Coder has bash access). Bounded: candidates run in the informal spec's order, stop at the first that meets the bar; model/package downloads go to tool caches (HF/uv/docker), never into the repo. If no CUDA GPU is visible at build time, STOP and ask (Stop-and-Ask matrix) — do not silently fall back to CPU-only without recording it as path C.
- OQ-029-02 RESOLVED — spike report path **`specs/029-local-judgment-backend/35-spike-report.md`** confirmed. The artifact layout is a required-minimum, not a ceiling; `35-` sorts after `30-report.md` and marks it as an evidence artifact. Requirement: the key results tables (VRAM, latency, accuracy, calibration) must be copied into ADR 0005 and the verification report so the evidence survives spec archiving.

## Task 2 — Backend switch in `scripts/typed-judgment.sh`

Add `JUDGMENT_BACKEND` (`local` | `hosted`, default `hosted`) to the typed-judgment wrapper. Hosted path remains byte-identical to spec 028 behavior. Local path makes `JUDGMENT_API_KEY` optional and handles both Kev and CLM response shapes.

**Acceptance criteria:**

- `JUDGMENT_BACKEND` unset or empty → treated as `hosted`. All 66 existing bats tests pass untouched.
- `JUDGMENT_BACKEND=hosted` → behavior byte-identical to unset. `configured_credentials()` still requires both `JUDGMENT_API_URL` and `JUDGMENT_API_KEY`. `JUDGMENT_MODEL` still required (exit 2 if missing).
- `JUDGMENT_BACKEND=local` → `JUDGMENT_API_URL` required; `JUDGMENT_API_KEY` optional; `JUDGMENT_MODEL` optional.
- `JUDGMENT_BACKEND=local`, `JUDGMENT_API_URL` set, `JUDGMENT_API_KEY` unset → request sent without `Authorization` header (or with a dummy header only if the spike report documents the server requires one — the spike report is the authority).
- `JUDGMENT_BACKEND=local`, `JUDGMENT_API_URL` set, `JUDGMENT_API_KEY` set → `Authorization: Bearer <key>` header sent, same as hosted.
- `JUDGMENT_BACKEND=local`, `JUDGMENT_API_URL` unset → exit 10 (fallback, same as hosted with missing URL).
- `JUDGMENT_BACKEND` set to any value other than `local` or `hosted` → exit 2 (usage error).
- Response normalization (`normalize_output`) handles Kev response shape (body includes `latency_ms` per-answer) and CLM response shape (body includes `billing_units` per-answer, ignored by normalization; `X-CLM-Latency-Ms` response header, not parsed). No changes to `normalize_output` required — verify this with mock tests for both shapes.
- Existing retry logic (max 3 attempts, exponential backoff on retryable statuses), daily cap, confidence threshold, diagnostic truncation, and dry-run mode all function identically in both backend modes.
- New bats tests added to `scripts/tests/typed-judgment.bats` covering: backend switch matrix (unset/hosted/local/invalid), local auth header presence/absence, Kev mock response parsing, CLM mock response parsing, local server-down fallback, local cap behavior. All new tests use the fake-transport pattern from spec 028 (no real HTTP).
- All 66 existing bats tests in `scripts/tests/typed-judgment.bats` and `scripts/tests/typed-judgment-integration.bats` pass without modification.

**Resolved (pre-/build, human ruling):**

- OQ-029-03 RESOLVED — when `JUDGMENT_MODEL` is unset the **backend's default model is chosen**: in local mode the script sends the winning backend's default alias (`kev-latest` / `clm-latest`, whichever the spike report records), defined once as a top-of-script constant with a comment citing the spike report section. `JUDGMENT_MODEL` remains optional in local mode and overrides the default when set. Hosted mode is unchanged: `JUDGMENT_MODEL` still required (exit 2 when missing on a live call), byte-identical 028 behavior.

## Task 3 — `scripts/judgment-local-up.sh`

New script to start, stop, report status, and health-wait for the winning local backend recipe. Parameterized by the spike report (serving command, port, model identifier, process count).

**Acceptance criteria:**

- Script exists at `scripts/judgment-local-up.sh`, executable, with subcommands: `up`, `down`, `status`, `health`.
- `up` starts the winning recipe's process(es) (command and arguments from spike report), waits for the health endpoint to respond (bounded timeout, default 120s), and on success prints the exact `JUDGMENT_*` env lines to add to the per-machine env file.
- `up` when the server is already running and healthy → idempotent: no error, reprints env lines, does not start a duplicate process.
- `down` stops all processes started by `up`. Uses a PID file in a gitignored directory (`.cache/judgment-local/` or similar).
- `down` when no server is running → idempotent: no error, reports "not running."
- `status` prints `running` (with PID and port) or `stopped`, exits 0 in both cases.
- `health` polls the health endpoint and exits 0 when healthy, non-zero on timeout. Timeout is configurable via `JUDGMENT_LOCAL_TIMEOUT_SECONDS` (default 120).
- Script refuses to run as root (exits non-zero with a diagnostic).
- All logs and PID files go to a gitignored directory (`.cache/judgment-local/` or similar); `.gitignore` is updated to cover it.
- Model downloads use the tool's own cache (HF default `~/.cache/huggingface/`, uv default); no model files placed in the repo tree.
- Makefile target `judgment-up` and `judgment-down` added, invoking the script.
- New bats tests in `scripts/tests/judgment-local-up.bats` covering: up/down/status/health subcommands with a mock server (a trivial HTTP listener), idempotency of up and down, health-wait timeout, root refusal, PID file management.
- Script sources its parameterized values (command, port, health endpoint path) from variables at the top of the script, each with a comment citing the spike report section.

**Resolved (pre-/build, architect ruling):**

- OQ-029-04 RESOLVED — **one PID file per process**, in the gitignored run dir (`.cache/judgment/`): `encoder.pid` + `clm-serve.pid` for the CLM two-process recipe, a single `kev.pid` for the Kev recipe. Not a newline-separated list: per-process files give atomic writes, idempotent per-component `down`/`status`, clean partial-startup state, and one code path for both recipes. Stale PID files (process gone) are removed on `status`/`down`.

## Task 4 — Confidence recalibration and config templates

Compute the recommended `JUDGMENT_MIN_CONFIDENCE` for the winning backend from the spike's fixture distributions. Update config templates with the new backend switch and recalibrated threshold.

**Acceptance criteria:**

- `config/model.local.env.example` contains a commented `JUDGMENT_BACKEND=local` line with a comment explaining valid values (`local` | `hosted`) and the default (`hosted`).
- `config/model.local.env.example` contains a commented `JUDGMENT_API_URL` example for the local backend (URL with port from spike report).
- `config/model.local.env.example` contains a commented `JUDGMENT_MIN_CONFIDENCE` line with the recalibrated value from the spike report and a comment stating the method (e.g. "5th percentile of correct-answer confidence on spike fixtures").
- `config/model.local.env.example` retains the existing hosted-mode `JUDGMENT_API_URL`, `JUDGMENT_MODEL`, `JUDGMENT_DAILY_CAP` lines unchanged.
- `config/agent.local.env.example` retains the existing `JUDGMENT_API_KEY` line and adds a comment noting the key is optional when `JUDGMENT_BACKEND=local` (local backends may not require authentication).
- `scripts/check-no-hardcoded-secrets.sh` passes on the updated files.
- `scripts/tests/typed-judgment-integration.bats` gains content-contract tests verifying the presence of `JUDGMENT_BACKEND`, the local URL example, and the recalibrated threshold comment in `config/model.local.env.example`.
- All existing integration bats tests pass.

## Task 5 — ADR 0005: Local judgment backend

Document the architectural decision to add a local, free, open-source backend option for the typed-judgment layer.

**Acceptance criteria:**

- ADR exists at `docs/adr/0005-local-judgment-backend.md`.
- ADR states the billing-constraint change: the typed-judgment layer now supports an optional local compute backend alongside the hosted paid API.
- ADR documents the backend-switch semantics: `JUDGMENT_BACKEND` values, default, auth behavior per mode, optionality guarantees.
- ADR summarizes the spike results with measured numbers (VRAM, latency p50, accuracy, confidence distributions) — numbers must match the spike report.
- ADR documents the recalibrated `JUDGMENT_MIN_CONFIDENCE` with the method used to derive it.
- ADR extends (does not supersede) ADR 0004.
- ADR indexed in `docs/adr/README.md`.
- ADR respects the no-docs-mirror rule: provider/product names appear only in the ADR evidence section and config; general references say "local judgment backend."
- Content-contract test in `scripts/tests/typed-judgment-integration.bats` verifies ADR 0005 exists and contains the required sections (billing-constraint, backend-switch, spike summary, threshold).

## Task 6 — Documentation updates

Amend existing documentation to describe the local-backend mechanism.

**Acceptance criteria:**

- `docs/SPEC_PIPELINE.md` §Typed-judgment layer mentions the local backend option: `JUDGMENT_BACKEND=local` activates a local compute backend; the mechanism is provider-agnostic in this doc (no product names).
- `docs/LOOP_ENGINEERING.md` mentions the local backend as an option for loop-triage judgment calls (provider-agnostic wording).
- `okf/when-to-use-typesafe.md` (or equivalent OKF operator-content file) gains a "Local backends" section that may name Kev and CLM (scoped operator content, not general docs).
- `okf/log.md` gains an entry for the local-judgment-backend addition.
- No provider names (Kev, CLM, jaredpalmer, Contrastive-LM) appear in `agents/`, `skills/`, or general `docs/` files — only in config templates, ADR 0005, and OKF operator content.
- Content-contract tests in `scripts/tests/typed-judgment-integration.bats` verify: SPEC_PIPELINE.md mentions "local" in the typed-judgment section, LOOP_ENGINEERING.md mentions "local", OKF file has "Local backends" heading.
- All existing orchestration check scripts pass (`scripts/check-orchestration.sh`).

## Task 7 — Live E2E verification

Run both consumer question shapes (ci-triage classification, spec-ux applicability) against the live local server through `scripts/typed-judgment.sh`. Record results or document skip-with-reason.

**Acceptance criteria:**

- If the local server is running on the build machine: run ≥1 ci-triage-style question and ≥1 spec-ux-style question through `scripts/typed-judgment.sh` with `JUDGMENT_BACKEND=local`. Record in the spike report addendum: answer, confidence, latency_ms, usage tokens per question.
- Compare ≥1 real case's local-backend answer against the LLM fallback path's answer. Record agreement/disagreement in the spike report addendum (advisory, not a gate).
- If the local server is not available (no GPU in CI, no local stack installed): record a skip-with-reason entry in the spike report addendum stating why (e.g. "CI has no GPU," "target machine not accessible").
- The E2E transcript follows the run-log telemetry format from spec 028 (fields: question shape, backend, answer, confidence, latency_ms, usage, timestamp).
- No changes to consumer files (`skills/ci-triage/SKILL.md`, `agents/spec-ux.md`) — verify by diff showing zero changes to these files.

---

## Open questions summary

All resolved pre-`/build` (human + architect rulings recorded in each task section):

| ID | Resolution | Task |
|---|---|---|
| OQ-029-01 | Coder runs the spike during `/build` on this machine (GPU present); bounded, cache-only downloads; STOP-and-ask if no GPU visible | 1 |
| OQ-029-02 | `specs/029-local-judgment-backend/35-spike-report.md` confirmed; key tables copied into ADR 0005 + verification report for archive survival | 1 |
| OQ-029-03 | `JUDGMENT_MODEL` unset → script sends the winning backend's default alias (top-of-script constant citing spike report); optional in local mode, still required in hosted mode (028 behavior unchanged) | 2 |
| OQ-029-04 | One PID file per process in `.cache/judgment/` (`encoder.pid` + `clm-serve.pid`, or single `kev.pid`); stale files cleaned on status/down | 3 |
