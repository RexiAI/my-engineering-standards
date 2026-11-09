# Architecture Decision Record (ADR)

## Title

Telemetry ledger stays committed: the PR Opener commits `runs.jsonl`

## Status

Accepted

## Context

The spec pipeline appends one telemetry record per completed run to a tracked,
append-only `runs.jsonl` through `scripts/record-gate-run.sh` (spec 012), and
`scripts/gate-stats.sh` reads it for the weekly drift view. No stage committed
it: the PR Opener staged only task-named files plus `specs/NNN-slug/`, so every
successful `/build` left the ledger modified in the working tree. Re-running the
pipeline then hit the "working tree dirty" stop condition on a file the pipeline
itself had written.

Child repos made it worse. They consume this repo as a `.standards/` submodule,
so the Verifier invoked `.standards/scripts/record-gate-run.sh`; that script
resolved its default target from its own location and appended to
`.standards/runs.jsonl`, dirtying the pinned submodule checkout instead of the
child's tracked ledger. The child's own `runs.jsonl` is tracked and was not the
file being written.

Ignoring the file and truncating it are both wrong: it is deliberately tracked
and shipped in every child repo, and the trend survives merges only because the
records are committed.

## Decision

1. `scripts/record-gate-run.sh` and `scripts/gate-stats.sh` resolve the default
   ledger path to the **consuming** repo's work-tree top level. When the script
   lives inside a `.standards/` submodule, the resolver walks to the
   superproject; a plain checkout uses its own top level; a copied script outside
   any work tree keeps the historical script-parent default. `-f` and
   `GATE_RUNS_FILE` still override it.
2. The PR Opener commits the ledger with the commits it already makes: the
   stage-5b PR-record commit, the stage-5d archive commit, and a phase-2
   fix-round commit. Never inside a per-task commit, never gitignored, never
   truncated.
3. `docs/SPEC_PIPELINE.md §Commit and push carve-out` names this commit path, so
   committing `runs.jsonl` is inside the pipeline's stated exception rather than
   an unstated extra.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Gitignore `runs.jsonl` | No dirty tree | Deletes the trend from version control; contradicts the ledger's designed purpose and every child repo's history |
| Leave it dirty, clear it manually | No rule change | The next run stops on the pipeline's own artifact; the dirt recurs every successful run |
| Commit it inside a per-task commit | No extra commit | Pollutes task scope and makes per-task commits non-reproducible from `10-tasks.md` |
| A dedicated telemetry commit per run | Clear history | Adds a commit without carrying the PR evidence the step-6/archive commits already carry |
| Keep the submodule-relative path in children | No path change | Appends to the pinned `.standards` checkout, which no child can commit or push |

## Consequences

A successful pipeline leaves a clean working tree, and each PR carries the
telemetry records it produced. Because every spec PR now touches `runs.jsonl`,
concurrent spec branches must rebase and keep both append blocks — conflicts are
textual and resolved by appending, never by dropping the other branch's lines.
History gains no extra commit: the records ride the commits the PR Opener already
makes. Runs that stop before the PR Opener still leave the ledger dirty, exactly
as they leave every other uncommitted artifact.

## Compliance

`docs/SPEC_PIPELINE.md §Commit and push carve-out` and
`docs/spec-pipeline/pr-opener.md` define the commit scope;
`agents/spec-pr-opener.md` repeats the operative rule within the prompt cap.
`scripts/tests/gate-telemetry.selftest.sh` asserts both the superproject path
resolution and that the PR Opener prompt and stage file commit the ledger.

## Notes

- 2026-11-09: Decision recorded.
