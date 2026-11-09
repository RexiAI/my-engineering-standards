# ADR 0028 — Bound and scope mutation runs

## Status

Proposed (becomes Accepted on merge)

## Context

Stage 5a runs mutation testing on `production` and `multi-service` tiers. The
standing instruction was `npx stryker run`, plus "re-run until the suite is
mutation-clean". Neither is bounded.

In practice that produced a run that dominated the stage and still said little
about the change under review. On spec 007 (a Next.js child repo, 18 files in the
change surface) the full Stryker configuration instrumented the whole
`web/**` + `web/components/**` tree. The first invocation was interrupted by the
operator before it finished (it later completed and left a usable report); the
second was a full scoped run. Two whole-surface passes for one spec, with no
cache, no wall-clock cap, and a survivor loop that is unbounded by construction.

Three properties of the setup made this inevitable:

1. **No scope rule.** The mutate globs describe what is *instrumentable*, not what
   this change *touched*. Nothing told the agent to intersect the two.
2. **No cache.** Every run started from zero, so a re-run after killing survivors
   re-tested mutants that had not changed.
3. **No budget and no stopping rule.** "Re-run until clean" is an instruction to
   spend unbounded time. A threshold below the achieved score has no stopping
   condition inside the stage.

Mutation testing is a quality gate. A gate that cannot finish within a bounded
window, and whose result describes the whole repository rather than the change
under review, is being asked the wrong question.

## Decision

**Bound and scope every mutation run.**

1. **Scope by the change surface.** A spec-stage run mutates only the files changed
   since its base ref: `scripts/run-mutation.sh --base <ref>` passes `--since <ref>`
   to Stryker, so the project's `mutate` globs and the diff intersect. The whole
   tree is a release activity (`--all`), never a spec stage.
2. **Keep an incremental cache.** `stryker.config.*` sets `incremental: true` with a
   stable `incrementalFile`, so a re-run tests only mutants whose source or killing
   tests changed.
3. **Enforce a wall-clock budget.** Default 900 s (`MUTATION_BUDGET_SECONDS`). On
   expiry the partial report is kept and the exit code is 124; the stage records a
   scoped score and stops rather than hanging.
4. **Two passes, then stop.** One scope pass, at most one targeted survivor pass
   (`--only <survivor files>`). The unbounded retry loop is removed from the agent
   and the stage file. Below threshold after the survivor pass: record the score,
   name the survivors, and BLOCK.
5. **Read before you re-run.** An existing `reports/mutation/mutation.json` is
   evidence. If the change surface has not moved, consume it; do not start another
   scope pass.
6. **Label the score.** The report states whether the score is *scoped* (with the
   file list and no-coverage count) or *whole-tree*. One is never presented as the
   other.

The threshold stays at 80 % on covered code; the gate is not weakened. What changes
is the surface it measures and the time it is allowed to take.

### Alternatives Considered

| Alternative | Pros | Cons |
|---|---|---|
| Keep the whole-tree run and accept the cost | Maximum coverage per run | Minutes of CPU per spec, no cache, and the score describes code the change did not touch; it was the observed failure |
| Lower the threshold | Runs finish sooner | Changes a gate threshold to hide cost — forbidden across the pipeline |
| Disable mutation at `production` tier | Fastest | Removes the gate that proves tests catch bugs; contradicts `docs/CONFORMANCE_TIERS.md` |
| Run mutation only in CI, never in the stage | CI handles parallelism | Stage 5a gates the PR; moving it post-merge loses the pre-PR signal and lengthens the feedback loop |
| **Scope by diff, cache, budget, two passes** | Bounded, describes the change, reuses work | A scoped score can miss a regression in untouched code — covered by the pre-release whole-tree run |

## Consequences

- A spec-stage mutation run is bounded in wall-clock time and in what it mutates;
  the stage returns a verdict instead of an indeterminate job.
- Scores become comparable per change surface, not per repository — and the report
  must say which. Aggregate whole-tree numbers remain a release metric.
- The incremental cache becomes a build artifact that must not be committed
  (`reports/` is already ignored in the child repos that use it).
- The first run on a new file surface still pays full cost for those files; that
  cost is now proportional to the change, not to the repository.

## Compliance

- `scripts/run-mutation.sh` is the only supported entry point; it enforces the
  scope, the cache and the budget, and prints both score denominators.
- `agents/spec-mutation-runner.md` and `docs/spec-pipeline/mutation-runner.md`
  carry the two-pass rule and the prohibition on an unbounded retry loop.
- `docs/TESTING.md §Bounded, scoped mutation runs` states the same rule for humans.
- `ci/templates/stryker.conf.json` ships `incremental`, `incrementalFile`,
  `concurrency` and a JSON reporter, so a bootstrapped child repo starts bounded.
- `scripts/check-orchestration.sh` verifies that every `scripts/…` path cited by an
  agent resolves; `docs/adr/README.md` indexes this record.
- The threshold is unchanged. A gate FAIL is still fixed in code, never by editing
  the threshold.

## Notes

- 2026-11-09: Decision recorded after the spec 007 run, where two whole-surface
  Stryker passes dominated the stage and the first invocation was interrupted by
  the operator.
