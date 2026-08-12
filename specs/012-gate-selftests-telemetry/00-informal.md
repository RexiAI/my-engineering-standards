# Gate self-tests + run telemetry

Two capabilities, both model-free:

1. **Self-tests.** A `scripts/check-code-principles.selftest.sh` that generates
   throwaway fixtures (one per gate: a >6-complexity method, a duplicated block,
   a fat interface, etc.), runs the checker, and asserts each gate fires with the
   right severity. Wired into self-ci. Same for check-scenario-traceability.sh if
   feasible. Prevents "gate exists but never fires" regressions.

2. **Run telemetry.** Append-only `runs.jsonl` per repo: { runId, jiraKey/specSlug,
   gatesFailed[], loopCount, phase1Retries, phase2Retries, warnings[], durationSec,
   outcome }. The verifier appends one record per run; a weekly view surfaces
   which gate fails most and whether retry counts are creeping up — the actual
   drift signal the architecture exists to catch.

## Acceptance criteria

- AC-001: selftest scripts exist, exercise every gate, and are wired into self-ci.
- AC-002: gate scripts accept a `-ReportPath`/`-BaseRef` for telemetry output.
- AC-003: verifier appends a runs.jsonl record per completed run.
- AC-004: a small `scripts/gate-stats.sh` prints failure/retry rates from runs.jsonl.
