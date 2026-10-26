# 034-judgment-preflight-fail-open

> Spec pipeline archive. Original source: `specs/034-judgment-preflight-fail-open/` (deleted by this script).
> Archived: 2026-10-26

## Original ask

# Informal spec: judgment preflight, fail-open consumer contract

## The ask

Make the local judgment backend (`make judgment-up`) mandatory, to reduce tokens.
Owner's chosen interpretation: **mandatory to attempt, fail-open to continue** —
a preflight that tries the fast-path, warns once when it is unavailable, and never
halts the pipeline.

## Evidence gathered this session (verified)

1. **The fast-path already blocked a stage.** `spec-ux` returned `BLOCKED` when
   `localhost:8009` was down, even though the backend is opt-in and the pipeline
   is supposed to survive its absence.
2. **The consumer contract has drifted.** `docs/SPEC_PIPELINE.md` §Typed-judgment
   layer says exit `10` is load-bearing: "consumers treat it exactly like 'no
   fast-path exists'" and "run [their original procedure] on any exit `10`".
   `agents/spec-ux.md` instead maps every exit `10` to `BLOCKED`. The agent
   contradicts the document. The document is authoritative.
3. **Liveness is not fitness.** After `make judgment-up`, `/v1/models` returned
   200 while the inference path died on a 21.9 KB payload:
   `RuntimeError: !handles_.at(i) INTERNAL ASSERT FAILED ... CUDACachingAllocator.cpp:432`.
   The crash threshold sits between 12 KB and 21.9 KB. A preflight that only
   pings `/v1/models` would report healthy and then fail every real call.
4. **Tokens are not spent on judgment.** `scripts/token-stats.sh` on this machine:
   2,575M tokens, **95.18% cache_read** (context re-sent each turn). Small
   classification calls are noise by comparison. The preflight is a reliability
   and cost-hygiene feature, not the main token lever.

## Required behavior

1. **Preflight, fail-open.** At the start of `/spec` and `/build`, when
   `JUDGMENT_BACKEND=local`, run a bounded fitness probe: one small synthetic
   Choice request through `scripts/typed-judgment.sh`, not just `/v1/models`.
   - Healthy → record it and continue normally.
   - Unhealthy/unreachable → print exactly one warning line naming
     `make judgment-up`, record the fallback reason, and continue. Never exit
     non-zero, never block a stage.
   - `JUDGMENT_BACKEND` unset/hosted with missing config → silent, as today.
2. **Fix the exit-10 contract everywhere.** Audit every consumer of
   `typed-judgment.sh` and make exit `10` mean "no fast-path exists → run the
   stock procedure". For `spec-ux`, the stock procedure is its pre-spec-028
   applicability check. `BLOCKED` remains reserved for a genuine `ambiguous`
   answer, never for transport failure.
3. **Payload cap.** Consumers must not send an unbounded spec. Define a
   documented maximum state size (calibrate against the backend; default
   suggestion 12 KB) and truncate deterministically (head + tail + marker) before
   the call. A payload that would exceed the cap is a recorded fallback reason,
   not a crash and not a block.
4. **Telemetry.** `typed-judgment.sh` records the fallback reason distinctly:
   `unconfigured`, `unreachable`, `payload_overflow`, `error`. Consumers keep
   recording `fallback:true` with that reason in their judgment line.
5. **Operator surface.** `make judgment-status` reports liveness **and** payload
   fitness (small and max-size probes). `docs/SPEC_PIPELINE.md` setup lists
   `make judgment-up` as step 0, marked optional-but-recommended, with the
   measured token caveat above.
6. **Opt-in strictness.** `--require-judgment` (or
   `JUDGMENT_REQUIRED=1`) turns the preflight failure into a hard exit for
   operators who want it. Default is fail-open.
7. **Tests.** Prove: backend down → `/spec` and `/build` proceed with one warning;
   backend unhealthy for large payloads → deterministic truncation, no crash;
   healthy backend → fast path taken; no consumer maps exit `10` to `BLOCKED`
   (a static assertion over `agents/*.md`); ambiguous answer still blocks.

## Out of scope

- Fixing the CUDA allocator assert in the backend server itself (infra bug; the
  repo-side mitigation is the payload cap).
- Auto-starting the backend without an explicit operator command. The preflight
  warns; `JUDGMENT_AUTOSTART=1` may be considered, but is not required.
- Changing the judgment model or its confidence threshold.
- Making the backend a hard CI dependency.

## Open questions

Resolved by the owner's delegate on 2026-10-25. Override any at the human gate.

- OQ-1 — **ADR 0014 (renumbered from 0012, originally 0011).** `docs/adr/0011-clean-code-comment-gates.md`
  already exists on the in-flight `spec/032-clean-code-comment-hygiene` branch
  (PR #99). Reusing 0011 here would collide at merge. The two orphan ADR files
  (`0004-agent-model-agnostic-gate.md`, `0005-structural-cleanliness-gates.md`)
  are a pre-existing indexing defect; out of scope, do not renumber them.
  An ADR is required: ADR 0009's AC-024-01-12 rule makes a `agents/spec-*.md`
  edit without a `docs/adr/*.md` change fail the governance gate.
- OQ-2 — **12 KB cap, proven by bisect.** Task 2 must record the measured crash
  threshold; 12288 bytes is the starting value, not an assumption.
- OQ-3 — **Once per invocation**, cached for 300 s.
- OQ-4 — **Substring-pinned warning.** Must contain `make judgment-up` and
  `continuing without`; the exact sentence is free.
- OQ-5 — **Truncate, then send.** The call proceeds with deterministic head+tail
  truncation. Telemetry records `truncated:true` and the original byte size;
  `fallback` stays `false` when the answer is usable. Only an unusable answer
  (below threshold) or a transport failure is a fallback. This keeps the
  fast-path useful instead of disabling it on every large spec.

## Tasks

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

## Acceptance scenarios

## AC-034-01 — Unconfigured wrapper falls back with reason `unconfigured`
## AC-034-02 — Unreachable backend falls back with reason `unreachable`
## AC-034-03 — Daily cap exceeded falls back with reason `error`
## AC-034-04 — Below-threshold confidence falls back with reason `error`
## AC-034-05 — Reason line never leaks the key or an untruncated state
## AC-034-06 — Under-cap state is sent byte-identical
## AC-034-07 — Over-cap state is truncated head + marker + tail, then sent
## AC-034-08 — Truncation is deterministic
## AC-034-09 — Cap is configurable by flag and env, defaulting to 12288
## AC-034-10 — `--dry-run` prints the truncated body, never the full state
## AC-034-11 — Non-JSON string state over the cap is truncated as a string
## AC-034-12 — Healthy local backend is recorded, exit 0
## AC-034-13 — Backend down prints exactly one warning and exits 0
## AC-034-14 — Unset or hosted-unconfigured is silent
## AC-034-15 — `--require-judgment` turns a failed probe into a hard exit
## AC-034-16 — Probe result is cached; a second run within TTL does not re-probe
## AC-034-17 — `spec-pipeline` runs the preflight first for `/spec`
## AC-034-18 — `spec-pipeline` runs the preflight first for `/build`
## AC-034-19 — A preflight warning never halts stage delegation
## AC-034-20 — exit 10 runs the stock applicability check, never BLOCKED
## AC-034-21 — `ambiguous` answer still blocks
## AC-034-22 — `run` and `skip` answers are unchanged
## AC-034-23 — spec-ux telemetry records `fallback:true` plus a reason
## AC-034-24 — ci-triage exit 10 runs the stock classification unchanged
## AC-034-25 — ci-triage telemetry records a reason
## AC-034-26 — Reports liveness (running with pid and port, or stopped)
## AC-034-27 — Reports payload fitness with small and max-size probes
## AC-034-28 — Max-size probe failure is reported, not a crash
## AC-034-29 — Setup lists `make judgment-up` as step 0, optional-but-recommended
## AC-034-30 — Typed-judgment layer documents the contract and the new surface
## AC-034-31 — ADR records the contract change and the index is updated
## AC-034-32 — Static assertion: no consumer maps exit 10 to BLOCKED
## AC-034-33 — The new tests run offline with no live backend

## Verification

# Verification: 034-judgment-preflight-fail-open

- Attempt: 1 (first full run), phase 1
- Branch: `spec/034-judgment-preflight-fail-open` (dirty working tree, uncommitted)
- Base ref: `main` (6eb2c99)
- Verifier scope: re-execute every Coder/Refactorer claim; no production code written.

The two script gates below are transcribed verbatim (exit code + JSON), per the
script-is-authority rule. Where the design-principles gate was run both
unscoped and blame-scoped (`-BaseRef main`), the blame-scoped run is the
verdict for this change set; the unscoped run's pre-existing FAIL is out of
scope and flagged, not a pipeline stop.

---

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-10-26T02:38:12Z

```
{
  "checks": [1, 2],
  "passes": ["AC-034-01 — traced to a test", "AC-034-02 — traced to a test", "AC-034-03 — traced to a test", "AC-034-04 — traced to a test", "AC-034-05 — traced to a test", "AC-034-06 — traced to a test", "AC-034-07 — traced to a test", "AC-034-08 — traced to a test", "AC-034-09 — traced to a test", "AC-034-10 — traced to a test", "AC-034-11 — traced to a test", "AC-034-12 — traced to a test", "AC-034-13 — traced to a test", "AC-034-14 — traced to a test", "AC-034-15 — traced to a test", "AC-034-16 — traced to a test", "AC-034-17 — traced to a test", "AC-034-18 — traced to a test", "AC-034-19 — traced to a test", "AC-034-20 — traced to a test", "AC-034-21 — traced to a test", "AC-034-22 — traced to a test", "AC-034-23 — traced to a test", "AC-034-24 — traced to a test", "AC-034-25 — traced to a test", "AC-034-26 — traced to a test", "AC-034-27 — traced to a test", "AC-034-28 — traced to a test", "AC-034-29 — traced to a test", "AC-034-30 — traced to a test", "AC-034-31 — traced to a test", "AC-034-32 — traced to a test", "AC-034-33 — traced to a test"],
  "fails": []
}
```

Verdict: PASS — all 33 AC-034 scenario IDs traced to a test; every reference
resolves; no untraced behavior.

---

## Evidence: full test suite

command: make test-scripts   (run twice, as required)
exit: 0
at: 2026-10-26T02:38:38Z

Run 1 — `make test-scripts` exit 0, TAP plan `1..524`, 0 `not ok`. Run 2 —
`make test-scripts` exit 0, TAP plan `1..524`, 0 `not ok`. Representative
excerpt (run 1 tail, the new spec-034 tests):

```
ok 327 AC-034-12: healthy local backend is recorded, exit 0, one probe request
ok 328 AC-034-13: backend down prints exactly one warning and exits 0
ok 329 AC-034-14: unset backend or hosted-unconfigured is silent
ok 330 AC-034-15: --require-judgment or JUDGMENT_REQUIRED=1 turns a failed probe hard
ok 331 AC-034-16: probe result is cached; a second run within TTL does not re-probe
ok 332 AC-034-17: spec-pipeline runs the preflight first for /spec
ok 333 AC-034-18: spec-pipeline runs the preflight first for /build
ok 334 AC-034-19: a preflight warning never halts stage delegation
ok 335 AC-034-20: exit 10 runs the stock applicability check, never BLOCKED
ok 336 AC-034-21: an ambiguous answer still blocks
ok 337 AC-034-22: run and skip answers are unchanged
ok 338 AC-034-23: spec-ux telemetry records fallback plus a reason and admits truncation
ok 339 AC-034-24: ci-triage exit 10 runs the stock classification unchanged
ok 340 AC-034-25: ci-triage exit-10 telemetry records a reason
ok 341 AC-034-26: reports liveness with pid and port, or stopped
ok 342 AC-034-27: reports payload fitness for small and cap-sized probes
ok 343 AC-034-28: a failing max-size probe is reported, not a crash
ok 344 AC-034-29: setup lists make judgment-up as step 0, optional-but-recommended
ok 345 AC-034-30: typed-judgment layer documents the contract and the new surface
ok 346 AC-034-31: ADR records the contract change and the index is updated
ok 347 AC-034-32: no consumer maps exit 10 to BLOCKED
ok 348 AC-034-33: new tests run offline with no live backend required
ok 509 AC-034-01: unconfigured wrapper falls back with reason unconfigured
ok 510 AC-034-02: unreachable backend falls back with reason unreachable
ok 511 AC-034-03: daily cap exceeded falls back with reason error and no request
ok 512 AC-034-04: below-threshold confidence falls back with reason error
ok 513 AC-034-05: reason line never leaks the key or an untruncated state
ok 514 AC-034-06: under-cap state is sent byte-identical with no overflow reason
ok 515 AC-034-07: over-cap state is truncated head + marker + tail, still sent, exit 0
ok 516 AC-034-08: truncation is deterministic across invocations
ok 517 AC-034-09: cap defaults to 12288, honours the env var, and the flag wins
ok 518 AC-034-10: --dry-run prints the truncated body, never the full state
ok 519 AC-034-11: non-JSON string state over the cap is truncated as a string
ok 520 unit: invalid --max-state-bytes values are usage errors (exit 2, no request)
ok 521 unit: invalid JUDGMENT_MAX_STATE_BYTES is a usage error (exit 2)
ok 522 unit: a cap smaller than the marker still never exceeds the cap
ok 523 unit: state exactly at the cap is not truncated and emits no reason
ok 524 unit: successful under-cap call writes no reason line at all
```

Verdict: PASS — 524 tests, 0 failures, twice. No skipped/disabled tests.

---

## Evidence: complexity gate

command: scripts/check-code-principles.sh --gates complexity -BaseRef main --json
exit: 0
at: 2026-10-26T02:48:55Z

```
{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": []
}
```

Note on the "real linter": this change set contains no Go/Java/JS/Python/Rust
source — changed files are `Makefile`, `.sh`, `.bats`, `.md`, and one
`config/model.local.env.example`. `golangci-lint`/PMD/ESLint have no targets
(no `go.mod` in the repo). The cyclomatic-complexity heuristic in
`check-code-principles.sh` (this repo's authoritative complexity gate) reports
zero FAILs scoped to the diff. Refactorer's "no new complexity" claim holds.

Verdict: PASS.

---

## Evidence: design-principles gate

command: scripts/check-code-principles.sh -BaseRef main --json
exit: 0
at: 2026-10-26T02:38:32Z

```
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests"],
  "fails": [],
  "warns": []
}
```

For completeness, the unscoped whole-repo run
(`scripts/check-code-principles.sh --json`, exit 1) reports exactly one FAIL,
verbatim:

```
{ "message": "Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "7" }
```

That file is not in this change set (`git diff` does not touch it) and is a
pre-existing whole-repo debt, not introduced by spec 034. The blame-scoped
run (`-BaseRef main`) is the verdict for this change set: zero FAILs, zero
WARNs. Flagging the pre-existing FAIL to the Architect as out-of-scope debt.

Verdict: PASS (scoped to the change set).

---

## Evidence: scenario-to-behavior spot check

command: manual inspection of agents/spec-ux.md, scripts/typed-judgment.sh, scripts/judgment-preflight.sh against AC-034-07, AC-034-13, AC-034-20, AC-034-21
exit: 0
at: 2026-10-26T02:48:55Z

Checked four scenarios at random/representative spread and confirmed the test
assertions match the Given/When/Then, not merely that a same-named test exists:

- AC-034-20 (exit 10 runs stock applicability check, never BLOCKED): the test
  asserts `grep_file "$SPEC_UX" '\*\*exit 10\*\*' 'Applicability check \(first
  action, always\)'` plus a branch extraction that must NOT contain `BLOCKED`.
  I read `agents/spec-ux.md` lines 72-78 directly: the exit-10 branch routes to
  `# Applicability check (first action, always)` and records `fallback:true` +
  reason. Matches. The only `BLOCKED` emissions in the file are exit-0
  `ambiguous` (line 66) and the constraint line 209. Match confirmed.
- AC-034-21 (ambiguous answer still blocks): test asserts `"ambiguous"` +
  `BLOCKED —`. File line 66 emits `BLOCKED — <one question>` only for exit-0
  `ambiguous`. Matches.
- AC-034-07 (over-cap state truncated head + marker + tail, still sent, exit 0):
  test asserts `state_text` ≤ 12288 bytes, head-prefix, tail-suffix, marker,
  `payload_overflow`, one request, exit 0. I reproduced manually: a 25,030-byte
  state (newline-stripped) truncates to exactly 12,288 bytes, head
  `HEAD-012345678` prefix preserved, tail `TAIL-9876543210` suffix preserved,
  marker `[truncated: 12780 bytes omitted]`, stderr `reason=payload_overflow`
  + `truncated original_bytes=25030 cap_bytes=12288`, deterministic across two
  runs. Matches.
- AC-034-13 (backend down prints exactly one warning, exit 0): test asserts one
  stderr line containing `make judgment-up`, `continuing without`, and
  `unreachable`. I reproduced manually against a dead port: exactly one line,
  exit 0. Matches.

Verdict: PASS.

---

## Specific judgments requested

### Exit-10 contract (spec-ux) — PASS

Static assertion re-run by hand: `grep` across `agents/*.md` and
`skills/*/SKILL.md` finds exactly two consumers of the fast-path —
`agents/spec-ux.md` and `skills/ci-triage/SKILL.md` (Task 6's "only two"
claim holds). Neither maps `exit 10` to `BLOCKED`:

- `spec-ux.md` line 72-78: exit 10 → run `# Applicability check (first action,
  always)`, record `fallback:true` + reason, "do not halt the pipeline".
- `ci-triage/SKILL.md` line 103+: exit 10 → run the existing LLM classification
  procedure unchanged, never a block/escalation.

`BLOCKED` remains exclusively the exit-0 + `ambiguous` outcome. No drift.

### Fail-open preflight — PASS

With the live local backend running (`kev: running (pid 1361883, port 8009)`,
left untouched — unreachability was simulated via a dead port, never by killing
the server):

- Healthy (live backend 8009): `judgment-preflight: healthy (…)` exit 0.
- Unreachable (dead port): exactly one stderr line
  `judgment-preflight: local judgment backend unavailable (reason: unreachable)
  — continuing without the typed-judgment fast-path; run \`make judgment-up\` to
  start it`, exit **0** (fail-open).
- Silent (backend unset / hosted-unconfigured): exit 0, no output.
- `--require-judgment`: same warning, exit **1**.
- `JUDGMENT_REQUIRED=1`: same warning, exit **1**.

`/spec` and `/build` therefore proceed with exactly one warning and exit 0 when
the backend is down; strictness is opt-in. Matches AC-034-12…16.

### Payload cap / truncation — PASS (threshold claim: UNVERIFIED)

- Deterministic truncation at 12,288 bytes confirmed by hand: head + marker +
  tail, marker names the omitted byte count, result exactly 12,288 bytes,
  byte-identical across two runs.
- Telemetry confirmed: stderr carries `typed-judgment: reason=payload_overflow`
  then `typed-judgment: truncated original_bytes=25030 cap_bytes=12288`.
- "Usable truncated answer ⇒ fallback:false" is the documented + unit-tested
  contract (AC-034-07 exits 0 with a usable mock answer; both consumer files
  record `"truncated":true` + `"original_bytes":<n>` with `fallback:false`).
  The live backend returned a below-threshold answer on my synthetic garbage
  state (exit 10 `reason=error`), which is correct — the fallback was the low
  confidence, not the truncation.
- Crash-threshold claim (20,547 ok / 20,548 fail): **UNVERIFIED**. Recorded as a
  live bisection in ADR 0014 §Notes and §Context, but not independently
  re-measurable by me: the wrapper now caps every payload at 12,288 bytes
  before the request, so the pre-cap crash cannot be reproduced through the
  wrapper, and sending a raw oversized request directly would risk the running
  backend (which I was instructed not to kill). The cap is 8,260 bytes below
  the lowest measured failure, so it is safe regardless.

### Test amendments (AC-028-35, AC-028-36, AC-029-74) — PASS (reflect new contract)

- AC-028-35 before: `grep_file "$AGENT" 'exit 10' 'BLOCKED'` (asserted the
  defect). After: asserts `exit 10` → `Applicability check` and that the branch
  does NOT contain `BLOCKED`. Corrects the assertion to the fixed contract —
  the old test encoded the exact defect this spec fixes.
- AC-028-36 before: `grep_file "$AGENT" 'fallback' 'BLOCKED'` (asserted the
  defect). After: asserts fallback telemetry carries `"reason"` +
  `unconfigured`/`unreachable` and never blocks. Corrects the assertion.
- AC-029-74 before: `[ -z "$(git diff HEAD -- skills/ci-triage/SKILL.md
  agents/spec-ux.md)" ]` ("consumer files equal HEAD", a spec-029-only delta
  assertion). After: allows a non-empty delta only while spec 034 is in flight
  AND ADR 0014 is present, else still fails. This re-scopes the assertion to the
  documented-change rule (ADR 0014 Decision 6) — a legitimate, necessary
  amendment, since spec 034 must edit both files and ADR 0009's AC-024-01-12
  requires the ADR. Not a weakening of coverage; it preserves the "undocumented
  consumer-file edits fail" guard. Minor note (flag, not FAIL): it hardcodes the
  spec-034 / ADR-0014 escape hatch, so a future spec editing consumer files
  must amend it again.

### ADR 0014 / 0011 — PASS

- `docs/adr/0014-judgment-consumer-contract-fail-open-preflight.md` exists, is
  `Accepted`, follows the `templates/ADR.md` heading set (Title/Status/Context/
  Decision/Consequences/Compliance/Notes, plus Alternatives Considered).
- `docs/adr/README.md` index gains the `| 0014 | … | Accepted |` row.
- `scripts/check-pr-review.sh` AC-024-01-12 PASSes: "change set modifies
  agents/spec-*.md as a documented pipeline change — the same change set adds
  or modifies a docs/adr/*.md record". Governance requirement satisfied.
- `docs/adr/0011*` does not exist; no 0011 index row. 0011 remains
  reserved/untouched (ADR 0014 §Notes: "0011 is reserved by the unmerged PR
  #99").
- `scripts/check-governance.sh` exit 0.

### No live-backend dependency in tests — PASS

New/changed bats tests use the injected fake-curl transport (`BIN/curl`,
`MOCK_CURL_*`). The strings `make judgment-up` and `localhost:8009` appear only
inside content assertions (the warning substring, the docs/`model.local.env.example`
comment contract), never as a real invocation. AC-034-33 asserts this and
passes. `scripts/tests/test_helper.bash` now unsets the full `JUDGMENT_*` set
for a hermetic baseline. Both `make test-scripts` runs passed offline.

---

## No unaccounted behavior

- `scripts/check-post-pr-ci-loop.sh` AC-014-04-09 was amended to allow exactly
  `scripts/judgment-preflight.sh` in the orchestrator (`agents/spec-pipeline.md`)
  while keeping the blanket `scripts/` ban for every other reference. This is
  not a numbered task in `10-tasks.md`, but it is documented in ADR 0014 §Notes
  and is a required consequence of Task 4's wiring (the orchestrator now runs
  the preflight). Verified: `scripts/check-post-pr-ci-loop.sh .` exits 0 with
  "no 'scripts/' in agents/spec-pipeline.md outside the allowed
  judgment-preflight invocation (spec 034)". Accounted for.
- `scripts/tests/test_helper.bash` (hermetic `JUDGMENT_*` unset expansion) traces
  to AC-034-33. Accounted for.
- No other diff hunks lack a task/scenario/ADR trace.

---

## Overall verdict: PASS

Every gate ran and produced no findings against this change set. The only FAIL
in any run is a pre-existing, out-of-scope whole-repo complexity violation
(`skills/hallmark/site/examples/cobalt-01/script.js`), which the blame-scoped
gate correctly excludes. The crash-threshold measurement is recorded but not
independently re-verifiable without risking the live backend; it is flagged to
the Architect, not blocking. Architect may proceed.

## Quality gates

# Report: 034-judgment-preflight-fail-open

Stage 5a (Mutation Runner) + structural report for spec 034. Scope of the change
set: `scripts/typed-judgment.sh`, `scripts/judgment-preflight.sh`,
`scripts/judgment-status.sh` (new), `scripts/judgment-lib.sh` (new), `Makefile`,
`agents/spec-pipeline.md`, `agents/spec-ux.md`, `skills/ci-triage/SKILL.md`,
`config/model.local.env.example`, `docs/SPEC_PIPELINE.md`, `docs/adr/README.md`,
`docs/adr/0014-judgment-consumer-contract-fail-open-preflight.md` (new),
`scripts/check-post-pr-ci-loop.sh`, `scripts/tests/*.bats`,
`scripts/tests/test_helper.bash`. No Go/Java/JS/Python/Rust source is touched.

## Verifier verdict (carried forward)

**PASS** — `specs/034-judgment-preflight-fail-open/25-verification.md`,
`Overall verdict: PASS`, `- Attempt: 1 (first full run), phase 1`. All five
contract checks carry evidence blocks with command, exit, UTC timestamp, and raw
output. Mutation testing was therefore correctly gated on that PASS before this
stage ran.

## Conformance tier and mutation-testing applicability

Tier: **`mvp`** (harness default — this repo declares no tier).

Evidence for the tier ruling:

```
command: grep -n "Conformance tier: production" AGENTS.md AGENTS_*.md
exit: 2
at: 2026-10-26T02:54:21Z

(no match — exit 2, no output: no `Conformance tier:` declaration exists in
AGENTS.md or any AGENTS_*.md, so per docs/SPEC_PIPELINE.md §Stop-and-Ask decision
matrix ("Project type ambiguous … defer to the harness default (`mvp` tier)") and
docs/CONFORMANCE_TIERS.md §How to declare a tier, the effective tier is `mvp`.)
```

Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is the
Architect row that `mvp` **skips**; the stage still runs (this report), the
mutation *gate* does not.

## Mutation score

```
command: make mutation
exit: 0
at: 2026-10-26T02:54:31Z

skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)
```

**Mutation score: skipped — `mvp` tier.** (`make mutation`'s own tier detection
is the same `grep "Conformance tier: production" AGENTS.md AGENTS_*.md` the
evidence above resolves, so the skip is the repo's own declared gate behavior,
not this agent's judgment call.)

### Compounding reason: no shell mutation lane exists

Independently of the tier, the change set is bash-only and this repo ships no
mutation runner for shell. Evidence:

```
command: command -v gremlins; command -v go-mutesting; command -v stryker; ls stryker.conf.json .strykerrc.json; ls pom.xml go.mod package.json
exit: gremlins=1, go-mutesting=1, stryker=1, stryker_conf=2, build_files=2
at: 2026-10-26T02:54:40Z

(no gremlins, no go-mutesting, no stryker on PATH; no stryker config; no pom.xml,
go.mod, or package.json at the repo root — none of the three mutation lanes in
docs/TESTING.md §Mutation Testing has a target in this repository at all.)
```

`docs/TESTING.md §Mutation Testing` enumerates exactly four lanes — Java
(`PiTest`, `mvn verify -Pmutation`), Go (`gremlins unleash`), JS/TS (`npx stryker
run`), React Native (Stryker/Jest) — and `docs/SPEC_PIPELINE.md §Tooling by
language` lists the same three-language set (Java / Go / JS-TS). Shell has no
entry in either table, so a `.sh`/`.bats` change set has no configured mutator
and no ≥80% score to report. Recorded skip with evidence, per the decision
matrix — not a blocked gate.

## Equivalent mutants

**None — no mutation run was performed**, therefore no surviving mutants exist
and no equivalent (un-killable) mutant can be named. This is not a claim that the
shell code is mutation-clean; it is a statement that no mutator executed against
it, so the concept does not apply to this run. If a bash mutation lane is adopted
later, the kill surface for these four scripts is the 524-test bats suite
(`scripts/tests/*.bats`), which is where such a lane's survivors would have to
be killed.

## Complexity summary (carried from the Refactorer, re-recorded by the Verifier)

The Refactorer leaves no artifact by design; its complexity/duplication/
property-test claims were re-executed by the Verifier and are re-run here.

```
command: scripts/check-code-principles.sh --gates complexity -BaseRef main --json
exit: 0
at: 2026-10-26T02:54:26Z

{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": []
}
```

- Cyclomatic ≤6 gate: **PASS**, zero FAIL, zero WARN, blame-scoped to the change
  set (`-BaseRef main`), matching the Verifier's own run
  (`2026-10-26T02:48:55Z`, identical JSON).
- Coverage caveat, stated so the PASS is not over-read: the gate's scanned
  extensions are `java, go, ts, tsx, js, jsx, py, rs`
  (`scripts/check-code-principles.sh` line ~400). **`.sh` is not among them**, so
  for this bash-only change set the gate passes vacuously — it does not measure
  the changed files. Recorded as a gate-scope limitation, not a defect in the
  change set.
- Supplementary measurement (not a gate, not blocking): the same decision-point
  heuristic the gate applies to other languages (`if`/`elif`/`for`/`while`/
  `case`/`&&`/`||`), counted per shell function across the four scripts —
  **max CC = 5** (`typed-judgment.sh:call_api`, `typed-judgment.sh:check_callable`),
  next highest 4 (`judgment-status.sh:main`), every other function ≤3. Under the
  ≤6 rule.
- Property tests: **skipped — `mvp` tier** (Refactorer property-test row is
  `production` and above; `make property-tests` prints the same tier skip).
- Duplication: no DRY FAIL/WARN in the scoped design-principles run (the
  duplicated probe/cap logic was extracted into `scripts/judgment-lib.sh`, which
  is what removed it).

## Gate results carried forward

| Gate | Result | Evidence |
|---|---|---|
| Verifier verdict | PASS | `25-verification.md` §Overall verdict (attempt 1, phase 1) |
| Scenario traceability | PASS — 33/33 AC-034 IDs traced, 0 fails | `25-verification.md` §Evidence: scenario traceability, exit 0 |
| Full test suite (Verifier, ×2) | PASS — 524 tests, 0 `not ok`, both runs | `25-verification.md` §Evidence: full test suite, exit 0 |
| Complexity gate | PASS — 0 FAIL / 0 WARN, scoped | `25-verification.md`, re-run above |
| Design-principles gate (scoped) | PASS — 0 FAIL / 0 WARN | `25-verification.md` §Evidence: design-principles gate, exit 0 |
| Design-principles gate (whole repo, unscoped) | FAIL ×1 — pre-existing, out of scope | see §Out-of-scope findings |
| Scenario-to-behavior spot check | PASS — 4 scenarios read against their assertions | `25-verification.md` |
| Mutation testing | SKIPPED — `mvp` tier (and no shell lane) | this report §Mutation score |
| Bash syntax (`bash -n`, 4 scripts) | PASS — `scripts/typed-judgment.sh`, `judgment-preflight.sh`, `judgment-status.sh`, `judgment-lib.sh` | run at 2026-10-26T02:54:2x Z, exit 0 |

ShellCheck: **not run — not installed on this machine** (`command -v shellcheck`
exits 1). No lint claim is made for the shell sources.

## Final test status (full suite, one final time)

Re-run after the mutation stage, because mutation-kill work would have been new
test code the Verifier never saw. No mutation-kill tests were added (no mutator
ran), so the suite is byte-for-byte the Verifier's suite — re-confirmed anyway.

```
command: make test-scripts
exit: 0
at: 2026-10-26T02:51:01Z

TAP plan: 1..524
ok    lines: 524
not ok lines: 0
run completed at: 2026-10-26T02:54:02Z

tail (last 5 lines, verbatim):
ok 520 unit: invalid --max-state-bytes values are usage errors (exit 2, no request)
ok 521 unit: invalid JUDGMENT_MAX_STATE_BYTES is a usage error (exit 2)
ok 522 unit: a cap smaller than the marker still never exceeds the cap
ok 523 unit: state exactly at the cap is not truncated and emits no reason
ok 524 unit: successful under-cap call writes no reason line at all
```

**Final test status: GREEN — exit 0, 524/524, 0 failures, 0 skipped.**

## Remediation record

**none** — no BLOCK occurred during the run.

- Carried forward from `25-verification.md`: `- Attempt: 1 (first full run),
  phase 1` and `Overall verdict: PASS`. The Verifier reached PASS on its first
  attempt, so no Phase 1 remediation cycle, no scoped re-verification, and no
  re-delegation to the Coder or Refactorer happened. No attempt count is
  consumed.
- Phase 2 (post-PR CI): not started — no PR exists yet (that is stage 5b). No
  entries to carry.
- Phase 3 (deploy verification): not started; non-frontend lane in any case.
- Orchestrator loop summary: no BLOCK entries were passed to this stage.
  Nothing is inferred or invented here.

## Out-of-scope findings (recorded, not fixed — decision-matrix `mvp` behavior)

1. Whole-repo design-principles run (`scripts/check-code-principles.sh --json`,
   exit 1) reports one pre-existing FAIL, unrelated to this change set:
   `./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10`. The file is
   not in `git diff` for this spec; the blame-scoped run is the verdict for the
   change set. Proposed follow-up: a small lint/complexity cleanup spec for
   `skills/hallmark/site/examples/`.
2. Verifier's flag (not a FAIL): `scripts/tests/typed-judgment*` assertion
   AC-029-74 hardcodes the spec-034 / ADR-0014 escape hatch, so the next spec
   that edits consumer files must amend it again. Proposed follow-up: generalize
   the assertion to "documented change = ADR present in the same change set".
3. Complexity-gate blind spot for `.sh` (see §Complexity summary). Proposed
   follow-up, only if shell keeps growing: extend
   `scripts/check-code-principles.sh` to a bash decision-point heuristic, with
   the ≤6 threshold unchanged (gate config is not something a pipeline agent
   changes).

## Pipeline gate (audit trail) — run before the final status below

```
command: scripts/check-audit-trail.sh 034-judgment-preflight-fail-open
exit: 0
at: 2026-10-26T02:54:57Z

PASS 034-judgment-preflight-fail-open: 10-tasks.md present and non-empty
PASS 034-judgment-preflight-fail-open: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 034-judgment-preflight-fail-open: 25-verification.md present and non-empty
PASS 034-judgment-preflight-fail-open: 30-report.md present and non-empty
PASS 034-judgment-preflight-fail-open: evidence block 'scenario traceability' — command: scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-10-26T02:38:12Z
PASS 034-judgment-preflight-fail-open: evidence block 'full test suite' — command: make test-scripts   (run twice, as required), exit: 0, at: 2026-10-26T02:38:38Z
PASS 034-judgment-preflight-fail-open: evidence block 'complexity gate' — command: scripts/check-code-principles.sh --gates complexity -BaseRef main --json, exit: 0, at: 2026-10-26T02:48:55Z
PASS 034-judgment-preflight-fail-open: evidence block 'design-principles gate' — command: scripts/check-code-principles.sh -BaseRef main --json, exit: 0, at: 2026-10-26T02:38:32Z
PASS 034-judgment-preflight-fail-open: evidence block 'scenario-to-behavior spot check' — command: manual inspection of agents/spec-ux.md, scripts/typed-judgment.sh, scripts/judgment-preflight.sh against AC-034-07, AC-034-13, AC-034-20, AC-034-21, exit: 0, at: 2026-10-26T02:48:55Z
✔ Audit-trail check: specs/034-judgment-preflight-fail-open complete, verifier evidence recorded.
```

(The raw run emits `PASS`/`✔` in green ANSI; colour escapes stripped here, text
otherwise byte-identical. 9 PASS lines, 0 FAIL, exit 0 — no heading or missing
evidence to escalate, and `25-verification.md` was not touched by this stage.)

This gate was run **after** this file first existed and **before** the final
status line below, which is the ordering the stage requires.

## Final status

**GREEN — mutation stage complete, no blocking finding.**

- Verifier PASS carried forward; tier `mvp` so mutation testing is a recorded
  skip (not a gap), with the additional, independent reason that no shell
  mutation lane exists in this repo.
- Zero surviving mutants, zero equivalent mutants (no run).
- Complexity ≤6 gate PASS scoped to the change set; supplementary shell
  measurement max CC 5; `.sh` not covered by the gate's scanner (recorded).
- Full suite re-run after this stage: `make test-scripts` exit 0, 524/524, 0
  failures.
- Audit-trail gate: exit 0, complete.
- Remediation record: **none** (Verifier PASS on attempt 1, phase 1; no BLOCK).
- Nothing committed, pushed, or opened — that is stage 5b (the PR Opener).
  `PR:` line to be appended there.


## PR

PR: https://github.com/RexiAI/my-engineering-standards/pull/101
commit-count: 11 (branch head `2411185` when the draft PR opened; this record
commit is 12 on the branch)

Opened as a **draft** against `main` by stage 5b. Per `docs/SPEC_PIPELINE.md`
§Archive in the PR, the archive is **not** in this stage's scope — stage 5d
(the Archiver, same agent) runs `scripts/archive-spec.sh 034-judgment-preflight-fail-open`
as the pipeline's final act, after stage 5c's recorded deploy skip. Known
red on this head until then: `scripts/check-specs-archived.sh` (finished spec,
archive pending at 5d) and `specs/034-judgment-preflight-fail-open/40-deploy.md`
(pending at 5c).

## 40-deploy.md

# Deploy verification — 034-judgment-preflight-fail-open

Stage 5c (Deploy Verifier). Branch `spec/034-judgment-preflight-fail-open`,
PR https://github.com/RexiAI/my-engineering-standards/pull/101,
head SHA `95f5ba9a99c502c5ed25875c99fbb309ce2caaba`.

## Verdict summary

| Field | Value |
|---|---|
| Repo classification | non-frontend (standards/tooling repo: shell + markdown + bats, no application surface) |
| Deploy URL | none — no Vercel project linked, no deploy surface exists |
| Build status | skip |
| Health check status | skip |
| E2E verdict | skip |
| Timestamp (UTC) | 2026-10-26T02:58:29Z |
| Phase-3 attempt count | 0 of 3 (no attempt consumed — there is no deployment to verify) |

Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable

## Why skipped

The Deploy Verifier's scope is frontend child repos only: a repo is frontend if it
has a `vercel.json`, a `package.json` declaring Angular / React / Next.js / Ionic
web, or a connected Vercel Git integration. This repository has none of the three
(`scripts/check-audit-trail.sh`'s `frontend_repo()` keys off the two deterministic
filesystem signals, and the gate's own run below classifies it non-frontend). There
is therefore no preview URL to poll, no health endpoint to `curl`, and no live URL
to point the E2E runner at. Non-frontend repos never fail the deploy gate
(`docs/SPEC_PIPELINE.md` §Audit contract; AC-031-19).

No `vercel deploy` / `vercel deploy --prod` was run — Vercel's Git integration is
the sole source of truth for builds and deploys, and a CLI deploy would
double-build, race the Git integration for this commit, and leave an orphaned
deployment owned by no PR or branch. No `vercel inspect`, `vercel logs`,
`vercel ls`, or `vercel env pull` was run either: they are pointless without a
linked project, and no credential was read or echoed.

## Evidence: no `vercel.json` and no root `package.json` (frontend signal 1 + 2)

command: ls -d vercel.json package.json .vercel
exit: 2
at: 2026-10-26T02:58:24Z

```
ls: cannot access 'vercel.json': No such file or directory
ls: cannot access 'package.json': No such file or directory
ls: cannot access '.vercel': No such file or directory
```

## Evidence: no tracked `vercel.json` anywhere in the tree

command: git ls-files | grep -E '(^|/)vercel\.json$'
exit: 1
at: 2026-10-26T02:58:24Z

```
(no output — no match)
```

## Evidence: tracked `package.json` files declare no frontend framework

The repo tracks exactly two `package.json` files, neither at the root and neither an
application surface: one is a CI template fixture (vitest / fast-check / stryker /
eslint dev dependencies only), one is the media-voice helper script (name + engines
only, no dependencies).

command: git ls-files | grep -E '(^|/)package\.json$'
exit: 0
at: 2026-10-26T02:58:24Z

```
ci/templates/js-feature/package.json
scripts/media/voice-chat/package.json
```

command: grep -nE '"(next|react|@angular/core|@ionic/angular)"[[:space:]]*:' ci/templates/js-feature/package.json scripts/media/voice-chat/package.json
exit: 1
at: 2026-10-26T02:58:24Z

```
(no output — no match in either file)
```

## Evidence: no Vercel project linked (frontend signal 3)

No `.vercel/project.json` link file exists (see the `ls` output above), and no
committed file carries a project binding for this repo: every tracked
`VERCEL_PROJECT_ID` / `vercel link` mention belongs to the shipped child-repo lane
(`.github/workflows/ci-vercel-production-verify.yml`, which is `on: workflow_call`
only, plus its docs, script, agent definition, and bats tests) — not to a project
linked to this repository.

This is the same condition the pipeline records as
`No Vercel project linked to this repository` in the post-merge lane; here it is
subsumed by the stronger non-frontend classification.

## Phase-3 attempt accounting

Attempts consumed: **0 of 3**. Phase 3's budget counts fix-and-redeploy rounds.
A skip is not a failed round: no deployment was waited on, no build was inspected,
no health check ran, and no E2E suite was delegated, so nothing consumed budget and
no fix routing was triggered. Phase-1 and phase-2 counters are untouched by this
stage.

## Observation recorded, not routed (phase-2 CI state at time of this run)

Per `docs/SPEC_PIPELINE.md` §Deploy verification loop (phase 3), phase 3 starts
only after the phase-2 post-PR CI loop is green. At the time of this run the PR's
Self CI `Validate` job is **FAILURE**, so this observation is recorded verbatim for
the orchestrator and does not alter the SKIPPED verdict above — the skip is
flag-independent and derived from repo class, not from CI state.

The single failure cause across all four runs on this branch is
`scripts/check-specs-archived.sh`: spec 034 is *finished* (it has `30-report.md`)
but not yet archived. That is the documented pre-archive state — the archive is
stage 5d's final act, which runs only after stage 5c, so this check cannot be green
until 5d's archive commit lands. This stage does not commit, push, or archive
(5b/5d's carve-out), and does not route a repair: the finding is out of scope for
stage 5c.

command: gh pr checks 101 --json name,state,bucket,workflow
exit: 0
at: 2026-10-26T02:58:28Z

```
[{"bucket":"fail","name":"Validate","state":"FAILURE","workflow":"Self CI"},{"bucket":"fail","name":"Validate","state":"FAILURE","workflow":"Self CI"}]
```

command: gh run list --branch spec/034-judgment-preflight-fail-open --workflow "Self CI" --limit 4 --json databaseId,conclusion,headSha
exit: 0
at: 2026-10-26T02:58:29Z

```
[{"conclusion":"failure","databaseId":40261655686,"headSha":"95f5ba9a99c502c5ed25875c99fbb309ce2caaba"},{"conclusion":"failure","databaseId":40261651542,"headSha":"95f5ba9a99c502c5ed25875c99fbb309ce2caaba"},{"conclusion":"failure","databaseId":40261640598,"headSha":"24111853c22e94e7d32405c2a3d4bf3cfff488b6"},{"conclusion":"failure","databaseId":40261623561,"headSha":"24111853c22e94e7d32405c2a3d4bf3cfff488b6"}]
```

Failing check: `Validate` (workflow `Self CI`), run
https://github.com/RexiAI/my-engineering-standards/actions/runs/40261655686/job/121375133401
and run
https://github.com/RexiAI/my-engineering-standards/actions/runs/40261651542/job/121375121168.
Failed step: `Check finished specs are archived`. Verbatim log excerpt:

```
  [FAIL] 034-judgment-preflight-fail-open is finished (has 30-report.md) but not archived — missing docs/changes/034-judgment-preflight-fail-open.md
         Run: scripts/archive-spec.sh 034-judgment-preflight-fail-open (stage 5d does this automatically)
1 finished spec(s) not archived!
##[error]Process completed with exit code 1.
```

## Phase-2 CI verification (round 1)

Round 1 of 3. Post-PR CI check for PR #101, head
`98cba31086d691d8c74e63b14d2de9e60ec5045a` (branch
`spec/034-judgment-preflight-fail-open`). Scope per the task: "Wait for Self CI
on 98cba31 (push and pull_request)." A third check — `Review PR / Review PR`
(workflow `PR Review Agent`, the spec-024 self-hosted review agent) — was also
present on the head SHA and remained `in_progress` for the full ~26-minute
observation window; it is a separate, non-blocking workflow (per
`.github/workflows/pr-review.yml`: "Secret-guarded … check state 'skipped',
never 'failure', so the PR's required checks are unaffected") and is out of
scope for the Self CI verification. Recorded as pending, not a pass or fail.

### Per-check table

| Check | Workflow / event | Conclusion | Check-run ID |
|---|---|---|---|
| Validate | Self CI / push | success | 121375583946 |
| Validate | Self CI / pull_request | success | 121375596235 |
| Review PR / Review PR | PR Review Agent / pull_request | in_progress (pending) | 121375840063 |

### Evidence: gh pr checks (bucket)

```
command: gh pr checks 101 --json name,state,bucket,workflow,link,event
exit: 0
at: 2026-10-26T03:26:20Z

[
  {"bucket":"pending","event":"pull_request","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/40261808828/job/121375840063","name":"Review PR / Review PR","state":"IN_PROGRESS","workflow":"PR Review Agent"},
  {"bucket":"pass","event":"pull_request","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/40261808719/job/121375596235","name":"Validate","state":"SUCCESS","workflow":"Self CI"},
  {"bucket":"pass","event":"push","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/40261804585/job/121375583946","name":"Validate","state":"SUCCESS","workflow":"Self CI"}
]
```

### Evidence: check-runs via gh api (conclusions)

```
command: gh api repos/RexiAI/my-engineering-standards/commits/98cba31086d691d8c74e63b14d2de9e60ec5045a/check-runs --jq '.check_runs[] | {id, name, status, conclusion, started_at, completed_at}'
exit: 0
at: 2026-10-26T03:26:20Z

{"completed_at":null,"conclusion":null,"id":121375840063,"name":"Review PR / Review PR","started_at":"2026-10-26T03:00:25Z","status":"in_progress"}
{"completed_at":"2026-10-26T03:02:52Z","conclusion":"success","id":121375596235,"name":"Validate","started_at":"2026-10-26T02:59:28Z","status":"completed"}
{"completed_at":"2026-10-26T03:02:45Z","conclusion":"success","id":121375583946,"name":"Validate","started_at":"2026-10-26T02:59:25Z","status":"completed"}
```

### Evidence: "Check finished specs are archived" step

The step that previously failed is named `Check finished specs are archived`
and runs inside the Self CI `Validate` job. Both Self CI runs (push and
pull_request) report it `conclusion: success`.

```
command: gh run view 40261804585 --json jobs --jq '.jobs[] | {name, conclusion, steps: [.steps[] | {name, conclusion}]}'
exit: 0
at: 2026-10-26T03:26:53Z

(push Self CI — step of interest, verbatim:)
{"conclusion":"success","name":"Check finished specs are archived"}
```

```
command: gh run view 40261808719 --json jobs --jq '.jobs[] | {name, conclusion, steps: [.steps[] | {name, conclusion}]}'
exit: 0
at: 2026-10-26T03:26:53Z

(pull_request Self CI — step of interest, verbatim:)
{"conclusion":"success","name":"Check finished specs are archived"}
```

Both Self CI `Validate` jobs conclude `success`, and the full step list for
each run shows every step (including `Check finished specs are archived`,
`Check spec audit trails`, `make validate-all`, `Run shell gate bats tests`,
`Check scenario traceability (live tree)`) as `success`. No step concluded
`failure` or `cancelled` in either run.

### Verdict: PASS

Both Self CI checks on head `98cba31` — push (`Validate`, ID 121375583946) and
pull_request (`Validate`, ID 121375596235) — report `success`. The previously
failing `Check finished specs are archived` step now passes in both. No failing
check IDs to diagnose; nothing to fix. The pending `Review PR / Review PR`
check is out of scope (separate non-blocking workflow) and remains
`in_progress`; recorded, not a pass or fail.
