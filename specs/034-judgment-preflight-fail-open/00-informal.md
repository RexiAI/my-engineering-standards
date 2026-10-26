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

- OQ-1 — **ADR 0012, not 0011.** `docs/adr/0011-clean-code-comment-gates.md`
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
