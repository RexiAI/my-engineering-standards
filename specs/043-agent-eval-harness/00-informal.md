# Agent eval harness: prove a change made the pipeline better

Problem: we can prove the code obeys the gates, but not that an *agent* did the
right thing. Every acceptance test runs after the agent has already written
code, so a green gate set is consistent with an agent that read the wrong
files, skipped a stop condition, or was one prompt edit away from a silent
regression. There is no probe that scores an agent run end to end.

Read-only audit (2026-11-05):

1. `runs.jsonl` already records `specSlug`, `gatesFailed`, `warnings`,
   `durationSec`, `outcome`, `phase1Retries`, `phase2Retries`. Nothing consumes
   it — the data exists, the feedback loop does not.
2. No `evals/` tree. The only executable checks are `scripts/check-*.sh`, which
   assert repo structure and wiring, not agent behavior.
3. `scripts/check-scenario-traceability.sh` proves a test carrying the AC id
   exists and passes. It does not prove that probe would fail against a broken
   agent — that is exactly the gap that lets a weak probe grade everything green.

Want: a top-level `evals/` package (course material *about* the pipeline, never
shipped or loaded by it) with four parts.

1. **Task format.** `evals/tasks/NNN-slug/{instruction.md, environment/,
   tests/, solution/, task.toml}`. The verifier writes exactly one reward value
   on every exit path, including failure, so a crashed verifier scores 0 rather
   than disappearing.
2. **Runner.** Drives a real pipeline agent against a throwaway worktree and
   appends one record per run to `runs.jsonl`, reusing the existing schema so
   the miner in a later spec has a single data source.
3. **Oracle sanity in self-CI.** Every task must score 1 from its own
   `solution/` and 0 from an untouched `environment/`. Two directions, both
   required. A task that cannot fail is rejected at CI time, not discovered
   later.
4. **Three behavior probes**, written against gate outcomes rather than stage
   call counts (spec 039 lite mode is in flight and removes stages):
   - ambiguous informal spec → Specifier returns `BLOCKED` and no `10-tasks.md`
     is written;
   - a deliberately red gate → no stage-5 agent runs and no draft PR is opened;
   - `GH_TOKEN` absent → PR Opener refuses before any commit or push.

Out of scope, with reasons recorded in the ADR:

- Generic coding benchmarks (find-and-replace, csv-to-json, markdown-toc). They
  measure file-editing skill, not gate discipline; this pipeline's failure mode
  is the latter.
- Vendoring the upstream course repo. It is Apache-2.0 and this repo has no
  root `LICENSE`; we reuse patterns only and cite them.
- Modal, Opik, Kitaru, sandbox backends, and any hosted runner.

Measurable:

- Every task passes oracle sanity in both directions in self-CI.
- At least one deliberately broken agent variant (e.g. Verifier skips the real
  test run) is caught by at least one probe.
- A probe suite run appends valid `runs.jsonl` records that parse as JSON and
  match the existing schema.

Requires an ADR (`docs/GOVERNANCE.md`): this adds a CI gate and a new pipeline
surface. Depends on nothing. Spec 041 owns the token/context rules that would
otherwise overlap this scope.
