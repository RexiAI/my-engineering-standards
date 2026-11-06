# Architecture Decision Record (ADR)

## Title

Agent test output: filtered capture and reuse of an unchanged run

## Status

Accepted

## Context

Every pipeline stage that runs the suite pays for the log twice. The run itself
is the cheap part; the log is what costs — a full `make test` / `mvn test` /
`pytest` log is overwhelmingly passing lines, and pasting it into an agent's
context both burns tokens and buries the failures the agent is meant to read.
The same pressure pushes the other way at the end of the pipeline: the Verifier
runs the suite as the gate, and the Mutation Runner then runs it again even when
its own new tests are the only change — a second full run whose result the first
one already established.

Both savings are unsafe by default. Filtering output can hide the one line that
means "this failed"; reusing a run can skip a run that was actually needed. The
pipeline's value rests on the Verifier's run being real, so any token saving here
has to be a saving in *what is read*, never in *what is checked*.

## Decision

Two scripts, each with a stated fail-safe direction, and one rule that keeps them
from touching the gates.

**Filtered capture — `scripts/agent-test-summary.sh`.** `--run <log-path> --
<command…>` executes the real test command with combined stdout+stderr written to
`<log-path>`, prints only the signal lines plus one trailing
`SUMMARY: mode=… exit=… signal=… log_lines=… log=…` line, and exits with the
wrapped command's status verbatim. The complete log is never truncated, never
rewritten, and the stage appends it to `25-verification.md` under `## Raw log:
<check>` with a shell redirect — the evidence file keeps the whole thing at zero
context cost, and the evidence block points at it with `full log: §Raw log:
<check>`. `--read <log-path>` formats an existing log and exits 0 even when it is
full of failures: a formatter is not a gate, and neither is a filter. The caps
(`MAX_SIGNAL_LINES=50`, `MAX_OUTPUT_BYTES=8192`) are named constants, not flags,
so the context cost of a run cannot drift per invocation. A log path under a
`specs/` directory is refused before the command runs: evidence belongs in
`25-verification.md`, not as a scratch log inside the spec folder.

**Run reuse — `scripts/test-run-reuse.sh`.** A sha256 over the worktree — `git
rev-parse HEAD` (or `NO-HEAD`), the `git status --porcelain=v1 -z -uall` records,
and `git hash-object` per path (`DELETED` for a path that no longer exists) —
excluding the evidence files themselves (`25-verification.md`, `runs.jsonl`),
which would otherwise invalidate the hash the moment they were written. The
Verifier records the hash inside its `## Evidence: full test suite` block; the
Mutation Runner asks `--check <25-verification.md>`, which prints exactly one
line: `REUSE <hash>` on an exact match, or `RERUN <reason>` (`no-evidence-block`,
`exit-nonzero`, `hash-missing`, `hash-mismatch`) otherwise. Reuse is granted only
on an exact match against the current tree, so a mismatch can only ever cost a
redundant run, never skip one.

**Guarantees kept.** The Verifier owns the authoritative run and never reuses
anything; reuse is available to the Mutation Runner only, only after a Verifier
PASS. Mutation testing itself is never reused — no path skips, reuses, or
truncates the mutation run. Only test-suite output is ever filtered: the
design-principles gate and the complexity linters are invoked directly, so every
`FAIL` and `WARN` line is recorded verbatim as the gate contract requires. No
gate script, threshold, or gate outcome changes (`complexity 6`, mutation ≥80%,
agent cap 120, and every gate the stages invoked before are all unchanged) — this
decision moves procedure into scripts and changes what reaches context, not what
is checked.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Paste the full suite log into context | Zero new machinery; every line visible | Pays the token cost on every stage and buries the failures it exists to surface |
| Truncate the log file to its failures | One artifact, no pointer to follow | Destroys the audit trail; the evidence file can no longer carry the run verbatim |
| Per-framework quiet flags (`-q`, `--silent`) instead of a helper | No wrapper to maintain | Not portable across the repo's stacks, and several frameworks drop the failure detail too |
| Reuse keyed on file mtimes | Cheapest hash to compute | mtime is unreliable across checkouts, restores, and container layers — it can miss a real change |
| Reuse keyed on `git diff` alone | Simple and familiar | Misses untracked files, and the Mutation Runner's new tests are exactly untracked files |
| Let the Verifier reuse the Coder's run | Saves a second full run | Removes the independent gate — the one run the pipeline cannot do without |
| Record the hash in a side file | Keeps the evidence file untouched | Adds a state artifact the audit layout does not define, and a place for state to drift from the record |

## Consequences

A suite run now costs failures plus one line in context, while the full log
survives verbatim in `25-verification.md`, so a reader who needs detail follows a
pointer instead of paying for it up front. Stages share one capture recipe
(defined once, in `docs/spec-pipeline/verifier.md §Test-log capture`) instead of
improvising per framework, and that recipe is cited by every suite-running stage.
The Mutation Runner's final run becomes conditional on a mechanical tree check,
which means an unchanged tree saves a full run and a changed one is still run in
full — the direction of the fail-safe is deliberate, not incidental. The costs
accepted: an extra hash definition to keep true (it is part of the helper's
documented contract), one more indirection for anyone reading evidence, and the
discipline that anything the gates judge must never be routed through the filter.

## Compliance

`scripts/agent-test-summary.sh` and `scripts/test-run-reuse.sh` ship with
acceptance tests (`AC-041-09`–`AC-041-26` and `AC-041-27`–`AC-041-44` in the spec
041 acceptance set), including the refusal of a `specs/` log path, the exit-status
passthrough, the 50-line and 8,192-byte caps, the exclusion of the evidence paths
from the hash, and the rerun-on-any-mismatch cases. `AC-041-24` requires the
capture recipe to exist exactly once, so a stage cannot invent a second one.
`AC-041-42` and `AC-041-43` state the two hard invariants: mutation testing is
never reused, and the Verifier never reuses. `scripts/check-audit-trail.sh`
accepts the reuse form of the evidence block, and `scripts/check-agent-line-cap.sh`
plus `scripts/check-orchestration.sh` keep the citing prompts within the cap and
every cited path resolving. The gate scripts themselves are unchanged by this
decision; a future change to either helper's cap or hash definition is a pipeline
contract change and needs its own ADR.

## Notes

- 2026-11-05: Decision recorded (spec 041).
- 2026-11-05: Added in the phase-2 CI fix round as the ADR record for the spec's
  `agents/spec-*.md` changes (ADR 0009 requires one in the same change set).
