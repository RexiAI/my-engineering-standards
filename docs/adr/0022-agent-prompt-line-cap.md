# Architecture Decision Record (ADR)

## Title

Agent prompt line cap: procedure lives in stage docs and scripts, not in the prompt

## Status

Accepted

## Context

Every spec-pipeline agent prompt is loaded into context on each invocation. Four
of them had grown past 120 lines (`agents/spec-verifier.md` 246, `spec-ux.md`
219, `spec-pr-opener.md` 174, `spec-deployer.md` 141), because each new stage
rule was appended to the prompt instead of being placed where it is read only
when needed. The prompt then costs tokens on every run and buries the decisions
it exists to carry — the stop conditions, outputs, and information barrier.

Spec 037 already split `docs/SPEC_PIPELINE.md` into an index plus
`docs/spec-pipeline/<stage>.md` and added `scripts/measure-stage-read-cost.sh`,
which bounds what a stage must read (index + its stage file + its "Must read"
files) at 50% of the unsplit document. That bound means relocating procedure into
a stage file is not free: the extraction has to fit the stage's remaining read
budget, so compression matters as much as relocation.

## Decision

Cap every `agents/spec-*.md` at 120 lines, enforced by
`scripts/check-agent-line-cap.sh` (one named `MAX_LINES` constant), wired into
the `validate` job of `.github/workflows/self-ci.yml` and documented in
`AGENTS.md` alongside `check-skills.sh` and `check-orchestration.sh`.

The cap applies to the glob, not a hard-coded list, so the orchestrator agent
`spec-pipeline.md` is in scope by the same rule as the stage agents. Procedure —
ordered command lists, gate-run sequences, file-format templates — moves to the
stage doc under `docs/spec-pipeline/` (or a script under `scripts/`); the agent
keeps its decisions, stop conditions, outputs, and a path reference to each
extracted artifact.

Every gate the agents invoked before the change stays invoked: trimming moves
text, never a check, and no threshold value (complexity >6, skill line limit 500,
mutation tier) changes.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| No cap; review discipline only | Zero mechanism | Prompt growth is monotonic; cost is invisible per-PR |
| Cap in `check-skills.sh` | One fewer script | Conflates skill-spec validation with pipeline-prompt budget; different offenders, different threshold |
| Hard-coded list of in-scope agents | No glob surprises | A new stage agent escapes the cap silently |
| A larger cap (e.g. 200) | No trimming required | The four over-cap prompts stay over-cap; no behavior change |

## Consequences

Prompts get cheaper and more legible, and the cap catches regrowth at PR time.
Extraction is constrained by the 50% read-cost budget, so a stage file cannot
absorb procedure its stage has no budget for — the trim has to compress. Future
stage rules must be written at the level they are read (decision in the prompt,
procedure in the stage file), and raising the cap needs a spec that says why.

## Compliance

`scripts/check-agent-line-cap.sh` runs in self-ci's `validate` job with no
`continue-on-error`; `scripts/check-orchestration.sh` proves every path the
trimmed agents cite resolves; `scripts/measure-stage-read-cost.sh` proves each
stage still reads at most 50% of the baseline. The agent-prompt line cap is a
gate threshold: agents fix the prompt, never the constant.

## Notes

- 2026-11-01: Decision recorded (spec 038). Number 0018 is reserved by spec 040.
- 2026-11-05: Renumbered 0019 → 0020 at rebase; main had since taken 0018
  (spec 040) and 0019 (spec-ux design laws, #111).
