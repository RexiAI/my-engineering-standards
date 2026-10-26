# Tasks: judgment preflight, fail-open consumer contract

Spec 034. Turns the informal ask into eleven implementation units. The central
defect is a contract drift: `docs/SPEC_PIPELINE.md` §Typed-judgment layer says
exit `10` means "no fast-path exists → run the stock procedure", but
`agents/spec-ux.md` maps every exit `10` to `BLOCKED`. The document is
authoritative; the agent is wrong. Everything below either fixes that drift,
adds the fail-open preflight, caps the payload, or proves the behavior.

The Coder must reason from this file and `20-acceptance/` only. Every scenario
ID (`AC-034-NN`) becomes a test in the project's existing bats suite under
`scripts/tests/`; the ID goes in the test name exactly as in `docs/SPEC_PIPELINE.md`
§Scenario format.

---

## Task 1 — Fallback-reason taxonomy in `scripts/typed-judgment.sh`

Change: `scripts/typed-judgment.sh`

Add a machine-readable fallback reason to the wrapper, emitted on stderr in a
fixed format, so consumers and operators can distinguish *why* the fast-path
degraded. Reasons are exactly one of: `unconfigured`, `unreachable`,
`payload_overflow`, `error`.

Acceptance criteria:

- `fallback()` (currently `log_debug "$1 — fallback"; exit 10`) writes exactly
  one line to stderr in the format `typed-judgment: reason=<reason>` **before**
  exiting 10. The line is written regardless of `JUDGMENT_DEBUG` (it is not a
  debug-only line). `reason` is one of the four values below.
- The existing `fallback` calls are re-mapped to reasons as follows:
  - `not configured (JUDGMENT_API_URL/JUDGMENT_API_KEY)` → `unconfigured`.
  - `API call failed (HTTP <n>)` (transport failure after retries, or a
    non-200 status after retries) → `unreachable`.
  - `daily cap reached` → `error`.
  - `response unparsable or incomplete` → `error`.
  - `confidence below threshold` → `error`.
- Exit codes are unchanged: `0` usable answer, `10` fallback, `2` usage error.
  The reason line is additive; it does not change stdout (still the normalized
  JSON on success) or any exit code.
- The reason line never contains the API key value and never contains an
  untruncated state payload (the existing "never print the key or an untruncated
  state" rule extends to this new line).
- `payload_overflow` is **not** emitted by `fallback()`; it is emitted by the
  truncation path added in Task 2 (see Task 2 — truncation is a degradation of
  the payload, not an exit-10 fallback).

Verifying scenarios: AC-034-01, AC-034-02, AC-034-03, AC-034-04, AC-034-05.

---

## Task 2 — Payload cap and deterministic truncation in `scripts/typed-judgment.sh`

Change: `scripts/typed-judgment.sh`; add a commented entry to
`config/model.local.env.example` under the existing Typed-judgment section.

The local backend crashes on oversized payloads (the CUDA allocator assert
fires between 12 KB and 21.9 KB). The wrapper must never send a state payload
larger than a documented cap.

Acceptance criteria:

- New flag `--max-state-bytes <N>` and env var `JUDGMENT_MAX_STATE_BYTES`
  (default `12288` = 12 KB). The flag wins over the env var. A missing flag and
  unset env → the default. A non-positive or non-numeric value is a usage error
  (exit 2).
- `--max-state-bytes` is parsed in `parse_args` alongside the existing flags and
  surfaced in the `--help`/header comment block.
- After `load_state` and before `build_request`, when the serialized state
  (the raw `STATE` string, whether JSON or not) exceeds the cap in bytes, the
  wrapper truncates it deterministically to a string of at most the cap bytes:
  - the result is `HEAD + MARKER + TAIL`;
  - `HEAD` is a byte-prefix of the original state and `TAIL` is a byte-suffix of
    the original state (both ends are preserved; no content is invented);
  - `MARKER` is a fixed, deterministic string that names the number of omitted
    bytes (e.g. `\n…[truncated: <K> bytes omitted]…\n`);
  - `HEAD + MARKER + TAIL` is at most the cap bytes long.
- Truncation applies to both the JSON-embedded state and the string-embedded
  state: the truncated string is what `build_request` embeds.
- When truncation occurs, the wrapper emits `typed-judgment: reason=payload_overflow`
  on stderr (the Task 1 format) **and continues to make the HTTP call with the
  truncated state** — it does not exit 10 for truncation. A usable response still
  exits 0.
- `--dry-run` prints the *truncated* request body (so an oversized state shows
  the capped payload, never the full one).
- `config/model.local.env.example` gains a commented
  `# JUDGMENT_MAX_STATE_BYTES=12288` line under the Typed-judgment section.

Verifying scenarios: AC-034-06, AC-034-07, AC-034-08, AC-034-09, AC-034-10,
AC-034-11.

---

## Task 3 — Fail-open preflight script `scripts/judgment-preflight.sh`

Change: add `scripts/judgment-preflight.sh` (new, executable).

A bounded fitness probe for `/spec` and `/build`. It never blocks the pipeline
unless strictness is explicitly requested.

Acceptance criteria:

- New executable `scripts/judgment-preflight.sh` with a `set -euo pipefail`
  header consistent with the other scripts.
- Silent no-op: when `JUDGMENT_BACKEND` is not `local`, OR when
  `JUDGMENT_BACKEND=local` but `JUDGMENT_API_URL` is unset/empty, the script
  prints nothing and exits 0 without making any call. (Hosted with missing
  config stays silent, exactly as today.)
- Otherwise (local backend, URL set), run exactly one fitness probe: invoke
  `scripts/typed-judgment.sh` with a synthetic state payload of at most 1 KB and
  exactly one `choice` question, with `JUDGMENT_TIMEOUT_SECONDS` set to a small
  value (recommend 5) and `JUDGMENT_BACKOFF_SECONDS=0` so the probe is bounded
  (a single attempt, no backoff sleeps). The probe exercises the inference path
  through `typed-judgment.sh`, never a bare `/v1/models` ping.
- Healthy (probe exits 0): print exactly one line to stdout containing the word
  `healthy`, write the cached outcome (see cache criterion), and exit 0.
- Unhealthy/unreachable (probe exits 10 or any other non-zero): print **exactly
  one** line to stderr that contains the literal `make judgment-up`, the phrase
  `continuing without`, and the fallback reason word reported by the wrapper;
  write the cached outcome; and exit 0. Never exit non-zero on an unhealthy
  probe (that is the fail-open default).
- `--require-judgment` flag or `JUDGMENT_REQUIRED=1` env: on an unhealthy probe
  the script exits non-zero (recommend 1) instead of 0. `--require-judgment`
  wins; either form alone is sufficient to arm strictness. Default (neither set)
  is fail-open.
- Cache: the probe outcome is cached in a gitignored location
  (`${JUDGMENT_CAP_DIR:-<repo root>/.cache}/judgment-preflight`, a small text
  file holding `<epoch-seconds> <healthy|unreachable>`). A subsequent invocation
  whose cache is younger than `JUDGMENT_PREFLIGHT_TTL_SECONDS` (default `300`)
  reuses the cached outcome and does not re-probe; `--force` re-probes
  unconditionally. This realizes "once per invocation" for `/build`'s several
  stages.
- `--require-judgment`, `--force`, and `--max-state-bytes` (if forwarded) are
  the only flags; anything else is a usage error (exit 2).

Verifying scenarios: AC-034-12, AC-034-13, AC-034-14, AC-034-15, AC-034-16.

---

## Task 4 — Wire the preflight into `/spec` and `/build`

Change: `agents/spec-pipeline.md`

Acceptance criteria:

- `agents/spec-pipeline.md` instructs the orchestrator to run
  `scripts/judgment-preflight.sh` as its first action for **both** invocation
  modes (the `/spec` path and the `/build` path), before any delegation.
- The instruction states the fail-open rule: a non-zero preflight exit (only
  possible under `--require-judgment`/`JUDGMENT_REQUIRED=1`) is the only case
  that stops the run; a warning exit (0) never blocks any stage, and the
  orchestrator proceeds with delegation regardless.
- The bash permission allow-list in the agent frontmatter, if it enumerates
  scripts, allows `scripts/judgment-preflight.sh` (match the existing
  `scripts/typed-judgment.sh*` allow entry style).

Verifying scenarios: AC-034-17, AC-034-18, AC-034-19.

---

## Task 5 — Fix `agents/spec-ux.md` exit-10 contract

Change: `agents/spec-ux.md`

Acceptance criteria:

- The `exit 10` branch of the applicability fast-path no longer emits
  `BLOCKED`. It instead instructs the agent to run the stock applicability
  check — the `# Applicability check (first action, always)` section — unchanged,
  and to record `fallback:true` plus the wrapper-reported reason in telemetry.
- `BLOCKED` remains reserved exclusively for the `exit 0` + answer `ambiguous`
  case (unchanged behavior), never for transport/fallback.
- The `exit 0` + `run` → design path and `exit 0` + `skip` → `SKIPPED` path are
  unchanged.
- The sentence "no truncation of the payload itself" is removed or replaced:
  the wrapper now caps/truncates the state (Task 2), so the agent no longer
  claims the payload is sent untruncated.
- The telemetry line gains a `reason` field whose value is one of
  `unconfigured`, `unreachable`, `payload_overflow`, `error` (recorded on
  fallback; absent or null otherwise), alongside the existing `fallback`
  boolean.

Verifying scenarios: AC-034-20, AC-034-21, AC-034-22, AC-034-23.

---

## Task 6 — Audit `skills/ci-triage/SKILL.md`; add telemetry reason

Change: `skills/ci-triage/SKILL.md`

The ci-triage consumer already handles exit `10` correctly (runs the stock LLM
classification unchanged). Task 6 confirms that contract and adds the reason.

Acceptance criteria:

- The exit-10 handling in `skills/ci-triage/SKILL.md` is confirmed/kept correct:
  exit `10` runs the existing LLM classification procedure unchanged and never
  maps to a block. No change to that routing is required.
- The telemetry line on exit 10 gains a `reason` field with one of the four
  values (`unconfigured`, `unreachable`, `payload_overflow`, `error`),
  alongside the existing `judgment_fallback:true`.
- No other consumer files call `scripts/typed-judgment.sh` (the audit is
  `agents/*.md` plus `skills/*/SKILL.md`; `spec-ux` and `ci-triage` are the only
  two). If a third consumer is found it must be brought into the same exit-10
  contract in this task.

Verifying scenarios: AC-034-24, AC-034-25.

---

## Task 7 — Operator surface: `make judgment-status`

Change: add `scripts/judgment-status.sh` (new, executable); add a
`judgment-status` target to `Makefile`.

Acceptance criteria:

- New executable `scripts/judgment-status.sh` that reports liveness **and**
  payload fitness.
- Liveness: report `running (pid <n>, port <p>)` or `stopped` by reusing the
  same liveness signal as `scripts/judgment-local-up.sh status` (PID files in
  `${JUDGMENT_LOCAL_RUN_DIR:-<repo root>/.cache/judgment}` and/or the health
  endpoint). Always exit 0 for the liveness portion alone.
- Fitness: run two probes through `scripts/typed-judgment.sh` —
  1. a small synthetic `choice` request (state ≤ 1 KB), and
  2. a max-size request whose state is exactly the payload cap (`12288` bytes,
     or the configured `JUDGMENT_MAX_STATE_BYTES`) — so a backend that is
     "healthy" on `/v1/models` but crashes on large payloads is caught.
  Report pass/fail for each probe.
- Exit code: `0` when liveness reports running AND both probes pass; non-zero
  (recommend `1`) when the backend is stopped or either probe fails. A failing
  probe must not crash the status script itself (the max-size probe goes
  through the capped wrapper, so the request is at most cap-sized).
- `Makefile` gains a `judgment-status` target (`.PHONY` entry added) that
  invokes `scripts/judgment-status.sh`, placed alongside the existing
  `judgment-up`/`judgment-down` targets.

Verifying scenarios: AC-034-26, AC-034-27, AC-034-28.

---

## Task 8 — Docs: setup step 0 and the typed-judgment layer

Change: `docs/SPEC_PIPELINE.md`

Acceptance criteria:

- The setup section (near §Model configuration / One-time setup) lists
  `make judgment-up` as **step 0**, marked optional-but-recommended, with the
  measured token caveat: judgment classification calls are negligible next to
  the machine's ~95% cache-read token spend, so the backend is a reliability and
  cost-hygiene feature, not the main token lever.
- §Typed-judgment layer is updated so the exit-code contract is unambiguous:
  exit `10` means "no fast-path exists → consumers run their original
  (stock) procedure"; `BLOCKED`/halting is never a valid consumer response to
  exit `10`.
- §Typed-judgment layer documents the fail-open preflight
  (`scripts/judgment-preflight.sh`), the payload cap + deterministic truncation
  (`--max-state-bytes`, default 12 KB), the four telemetry reasons
  (`unconfigured`, `unreachable`, `payload_overflow`, `error`), and the
  `make judgment-status` operator surface.

Verifying scenarios: AC-034-29, AC-034-30.

---

## Task 9 — ADR: consumer contract + fail-open preflight

Change: add `docs/adr/NNNN-<slug>.md`; update `docs/adr/README.md`.

A short ADR recording the contract change, following ADR 0009's shape.

Acceptance criteria:

- A new ADR file at the next sequential number per the `docs/adr/README.md`
  index (currently `0011`), titled around "judgment consumer contract: exit-10
  = stock procedure, fail-open preflight, payload cap".
- The ADR records, with Context/Decision/Consequences: the exit-10 contract fix
  (exit 10 = run stock procedure, never BLOCKED), the fail-open preflight, the
  payload cap + deterministic truncation, and the four-way fallback-reason
  taxonomy.
- `docs/adr/README.md` index gains a row for the new ADR.
- **Note (dependency):** `scripts/check-pr-review.sh` AC-024-01-12 (per ADR
  0009) fails any change set that touches `agents/spec-*.md` without a
  `docs/adr/*.md` change in the same set. Task 5 edits `agents/spec-ux.md`, so
  this ADR is not optional — it is required for the change to pass the gate.
  The Coder must include both the spec-ux edit and the ADR in the same change
  set.

Verifying scenarios: AC-034-31.

---

## Task 10 — Tests: bats coverage incl. the static no-BLOCK assertion

Change: extend `scripts/tests/typed-judgment.bats`; add
`scripts/tests/judgment-preflight.bats` (new).

Acceptance criteria:

- Unit tests (in `scripts/tests/typed-judgment.bats`) cover Task 1 (each of the
  four reasons, exit codes preserved, redaction) and Task 2 (under-cap passthrough,
  over-cap truncation head+tail+marker ≤ cap, determinism, flag/env cap
  configuration, `--dry-run` reflection, string-state truncation).
- Integration/contract tests (in a new `scripts/tests/judgment-preflight.bats`)
  cover: the preflight's healthy/unhealthy/silent/strict paths (Task 3), the
  `spec-pipeline` wiring content contract (Task 4), the `spec-ux` exit-10 content
  contract (Task 5), the ci-triage exit-10 contract (Task 6), the
  `judgment-status` liveness + fitness + no-crash behavior (Task 7), and the
  docs/ADR content (Tasks 8–9).
- Static assertion (the "no consumer maps exit 10 to BLOCKED" test): a bats test
  that greps the consumer surface — `agents/*.md` and `skills/*/SKILL.md` — and
  fails if any file maps exit `10` to `BLOCKED` (e.g. a line matching an
  exit-10 → BLOCKED pattern). It must also assert the positive contract:
  `agents/spec-ux.md` routes exit `10` to the stock applicability check.
- Offline-safety: all new tests run with no `JUDGMENT_*` env vars set and no
  network (mocked HTTP via a trivial listener, as the existing
  `judgment-local-up.bats` and `typed-judgment.bats` do). No new test requires a
  live local backend.
- The scenario IDs `AC-034-01` … `AC-034-33` are cited by at least one test each
  (the traceability gate enforces this).

Verifying scenarios: AC-034-32, AC-034-33.

---

## Open questions (need a human answer before `/build`)

- **OQ-1 — ADR number.** The informal spec says "a short ADR 0012". The
  `docs/adr/README.md` index currently ends at `0010`, so the next free number is
  **0011**, not 0012. Tasks use `0011`. Confirm the number.
  (Housekeeping note: `docs/adr/0004-agent-model-agnostic-gate.md` and
  `docs/adr/0005-structural-cleanliness-gates.md` exist on disk but are absent
  from the README index — stale/renamed orphans, not blocking this spec.)
- **OQ-2 — Cap value.** Default pinned at `12288` (12 KB), from the observed
  crash threshold "between 12 KB and 21.9 KB". The informal spec asks to bisect
  the exact threshold before fixing the number; the Coder can proceed with
  12288 and the number is a single-line change if the bisect lands elsewhere.
- **OQ-3 — Preflight cadence.** "Once per invocation" is implemented as a
  cached result with `JUDGMENT_PREFLIGHT_TTL_SECONDS` default `300`. Confirm
  300 s is acceptable (a `/build` run's stages re-probe only after the TTL).
- **OQ-4 — Warning wording.** The exact warning sentence is pinned by substring
  contract (contains `make judgment-up` and `continuing without`) rather than a
  fixed sentence. Confirm the substrings are sufficient, or supply the exact
  wording.
- **OQ-5 — `payload_overflow` semantics (material).** The informal spec says both
  "truncate deterministically … before the call" (Required behavior 3) and
  "Consumers keep recording `fallback:true` with that reason" (Required behavior
  4). These pull in opposite directions. This spec resolves it as: truncate,
  then **still send** the truncated state (call proceeds, exit 0 if usable),
  and record `reason:payload_overflow` as a degradation — `fallback` stays
  `false` because a fast-path result *was* produced. Confirm this resolution;
  the alternative (treat `payload_overflow` as an exit-10 fallback that runs
  the stock procedure without sending) is a two-line change in Tasks 2/5/6 if
  preferred.
