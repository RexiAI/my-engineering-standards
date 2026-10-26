# Judgment consumer contract: exit-10 = stock procedure, fail-open preflight, payload cap

## Title

Judgment consumer contract: exit-10 means "run the stock procedure", fail-open
preflight, deterministic payload cap, and the four-way fallback-reason
taxonomy

## Status

Accepted

## Context

`docs/SPEC_PIPELINE.md` §Typed-judgment layer is the authoritative consumer
contract for the opt-in fast-path (ADR 0004, ADR 0005): exit `10` means "no
fast-path exists → run the stock procedure". Two shipped consumers had drifted
from it, and the local backend introduced a third failure mode:

1. **`agents/spec-ux.md` mapped every exit `10` to `BLOCKED`.** The document
   says exit `10` is exactly the case where the consumer keeps its original
   procedure; `BLOCKED` is reserved for a genuine ambiguous answer. Mapping
   transport failures to a halt turned an optional accelerator into a
   pipeline-stopper, and the prompt also claimed the state was sent with "no
   truncation of the payload itself".
2. **No fail-open preflight.** `/spec` and `/build` had no bounded way to know
   whether the configured local backend could actually answer before stages
   began delegating. A backend that was up but unable to infer (or too slow)
   would surface only later as repeated exit `10`s.
3. **Oversized payloads crash the local backend.** Live bisection on
   2026-10-26 measured the first failing JSON-shaped state at **20,548 bytes**
   (HTTP 500, `CUDACachingAllocator` internal assert; 20,547 bytes succeeded).
   The threshold drifts downward after a failing request because the allocator
   is left fragmented, and a repeated-character state failed later, at 29,869
   bytes, because token density differs from byte size. Any fixed byte cap
   must therefore sit well below the lowest observed failure, not at it.
4. **Fallback was indistinguishable from "nothing configured".** Every
   degradation was the same silent exit `10`, so operators could not tell an
   absent backend from an unreachable one, a cap from a low-confidence answer.

## Decision

1. **Exit-10 contract fixed in `agents/spec-ux.md`.** Exit `10` runs the
   stock applicability check (`# Applicability check (first action, always)`)
   unchanged and records `fallback:true` plus the wrapper-reported reason.
   `BLOCKED` is emitted only for exit `0` + answer `ambiguous`. The stale
   "no truncation of the payload itself" claim is removed: the wrapper caps
   and truncates the state before sending. `skills/ci-triage/SKILL.md`
   already ran its stock classification on exit `10`; it keeps that routing
   and gains the reason in telemetry.
2. **Fail-open preflight.** New `scripts/judgment-preflight.sh`, run as the
   first action of both `/spec` and `/build`. It is silent unless
   `JUDGMENT_BACKEND=local` and `JUDGMENT_API_URL` is set, then makes exactly
   one bounded fitness probe through `scripts/typed-judgment.sh` (≤ 1 KB
   synthetic state, one Choice question, 5 s timeout, no backoff, probe
   confidence threshold 0 — fitness, not calibration). Healthy: one stdout
   line plus a cached outcome. Unhealthy: exactly one stderr line
   naming `make judgment-up`, `continuing without`, and the reason, then exit
   `0`. `--require-judgment` / `JUDGMENT_REQUIRED=1` opts into a non-zero
   exit. The outcome is cached under
   `${JUDGMENT_CAP_DIR:-.cache}/judgment-preflight` for
   `JUDGMENT_PREFLIGHT_TTL_SECONDS` (default 300); `--force` re-probes.
3. **Payload cap with deterministic truncation.** `--max-state-bytes` /
   `JUDGMENT_MAX_STATE_BYTES` (default 12,288 bytes = 12 KB; the flag wins;
   non-positive or non-numeric is a usage error) caps the serialized state
   before the request is built. Over-cap state becomes `HEAD + MARKER + TAIL`
   where the marker names the omitted byte count and the whole string is at
   most the cap. The truncated payload is still sent: this is a degradation,
   not a fallback, so a usable answer exits `0`. Both the JSON-embedded and
   string-embedded state shapes are truncated. 12,288 sits 8,260 bytes below
   the lowest measured failure.
4. **Four-way fallback-reason taxonomy.** Every exit `10` writes exactly one
   `typed-judgment: reason=<word>` line to stderr, un-gated by
   `JUDGMENT_DEBUG` and never carrying the key or state content. The words are
   `unconfigured`, `unreachable`, `payload_overflow`, `error`. Truncation
   emits `payload_overflow` while continuing, plus one
   `typed-judgment: truncated original_bytes=<n> cap_bytes=<cap>` line so
   consumers can record `truncated:true` and the original size with
   `fallback:false`.
5. **Operator surface.** New `scripts/judgment-status.sh` and
   `make judgment-status` report liveness (the same PID-file signal as
   `scripts/judgment-local-up.sh status`) and payload fitness (a small probe
   and a probe whose state is exactly the cap), so a backend that answers
   liveness but fails on a full-size state is caught. Exit `0` only when
   running and both probes pass; a failing probe is reported, never crashes
   the status script.
6. **Test-contract amendments.** Spec 034 supersedes two spec 028 content
   assertions that encoded the old defect: AC-028-35 and AC-028-36 (exit `10`
   → `BLOCKED`) now assert exit `10` → the stock applicability check. The
   spec 029 delta assertion AC-029-74 ("consumer files equal HEAD") is scoped
   to the documented-change rule: a non-empty working-tree delta is allowed
   while this spec is in flight and ADR 0012 is present, and passes
   unchanged once the change is committed.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Keep exit-10 → `BLOCKED` in spec-ux | loud failures, no silent skip | makes an optional accelerator a pipeline-stopper; contradicts the authoritative document |
| Bare `/v1/models` liveness preflight | cheapest probe | cannot catch "alive but cannot infer" or payload-size failure — exactly the observed failures |
| Block on an unhealthy preflight by default | guarantees the fast-path works | turns an optional dependency into a hard requirement; violates the optionality guarantee (ADR 0004/0005) |
| Cap at the measured 20,548-byte threshold | largest accepted payload | threshold drifts downward under allocator fragmentation; a cap at the boundary crashes intermittently |
| Truncate to head only | simplest byte math | drops the tail of the spec/tasks file, which carries acceptance criteria and constraints |
| Treat `payload_overflow` as an exit-10 fallback | uniform "degraded ⇒ stock" rule | throws away a usable capped answer and re-runs the expensive procedure; resolved as a degradation instead (see Notes) |

## Consequences

- An unhealthy local backend no longer blocks `/spec` or `/build`: the
  preflight warns once and the pipeline continues without the fast-path. The
  cost is that a genuinely broken fast-path can stay broken silently unless
  the operator reads the warning or runs `make judgment-status`.
- Every consumer now has a machine-readable reason for each fallback, and the
  cache keeps `/build`'s several stages from re-probing within the TTL.
- State payloads above 12 KB are answered from a head+tail view rather than
  the full state. The cap is deterministic (identical input ⇒ identical
  request) so the telemetry and tests are reproducible.
- The local backend's oversized-payload crash class is prevented by
  construction: the wrapper never sends more than the cap, and the status
  surface proves the cap-sized path works.
- `BLOCKED` becomes meaningful again: it is a real ambiguity signal, not a
  catch-all for transport errors.

## Compliance

- `scripts/tests/typed-judgment.bats` pins AC-034-01…11: each reason word,
  unchanged exit codes, redaction, under-cap passthrough, head+marker+tail
  truncation ≤ cap, determinism, flag/env/default cap resolution, `--dry-run`
  reflection, and string-state truncation — all through the fake-curl
  transport.
- `scripts/tests/judgment-preflight.bats` pins AC-034-12…33: healthy /
  down / silent / strict / cached preflight paths; the `spec-pipeline`,
  `spec-ux`, and `ci-triage` content contracts; `judgment-status` liveness,
  both probes, and the no-crash max-probe failure; the docs and ADR content;
  and the static assertion that no file under `agents/` or `skills/*/SKILL.md`
  maps exit `10` to `BLOCKED`.
- `docs/SPEC_PIPELINE.md` §Typed-judgment layer is the authoritative contract;
  the setup section lists `make judgment-up` as step 0 with the token caveat.
- `make test-scripts`, `scripts/check-orchestration.sh`,
  `scripts/check-skills.sh`, `scripts/check-governance.sh`,
  `scripts/check-bats-assertions.sh`, and
  `scripts/check-code-principles.sh` remain green.

## Notes

- 2026-10-26: Decision recorded. Numbered 0012 because 0011 is reserved by the
  unmerged PR #99; it is the next free number for this change.
- 2026-10-26: Crash threshold measured live against the running local backend.
  JSON-shaped state: 12,288 bytes succeeded; 21,900 bytes failed in one run;
  a second bisect found 20,547 succeeding and 20,548 failing, with the
  boundary drifting lower on each retry after a failure. Repeated-character
  state failed at 29,869 bytes (29,868 succeeded), confirming the threshold
  tracks token density, not bytes alone. The 12,288-byte cap is deliberately
  below every measured failure.
- 2026-10-26: `payload_overflow` resolved as a degradation, not an exit-10
  fallback: the truncated state is sent, a usable answer exits `0`, telemetry
  records `fallback:false` with `truncated:true` and `original_bytes`. The
  emit order is `reason=payload_overflow` followed by the `truncated` line.
- 2026-10-26: `scripts/check-post-pr-ci-loop.sh` AC-014-04-09 is amended: the
  orchestrator prompt must stay free of `scripts/` references **except**
  `scripts/judgment-preflight.sh`, which Task 4 requires the orchestrator to
  run as its first action. Every other script reference still fails.
- References: ADR 0004 (typed-judgment layer), ADR 0005 (local backend),
  ADR 0009 (consumer contract and backend-aware credential gate),
  `docs/SPEC_PIPELINE.md` §Typed-judgment layer.
