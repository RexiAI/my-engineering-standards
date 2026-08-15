# Governance

This document states the non-negotiable governance constraints for the
standards repo and every project that consumes it. Governance is separated from operations.
The operational mechanics — how the pipeline actually runs — live in
`docs/SPEC_PIPELINE.md`, `docs/GIT_WORKFLOW.md`, and `AGENTS.md`. This document
names the constraints that bound that operation; `docs/SPEC_PIPELINE.md` is the
operational home for pipeline mechanics. Read it for how the pipeline runs;
read this document for what no pipeline change may violate.

## Trust Tiers

Every pipeline agent is assigned a trust tier: the highest action class its
`permission` frontmatter grants. T3 prohibitions apply to all agents regardless
of tier.

| Tier | Name | Capabilities |
|---|---|---|
| T0 | Autonomous | reads, gates, Jira/Confluence read, Jira comment |
| T1 | Local write | edit, commit, local branch |
| T2 | Confirm (human-triggered) | push, PR, Confluence publish, Jira transition |
| T3 | Forbidden | push to main, force-push, destructive infra |

**T3 is universal.** It applies to every agent, with no exceptions: no agent,
under any circumstance, may push to `main`/`master`, force-push, or run
destructive infra actions. This restates `AGENTS.md` and
`docs/GIT_WORKFLOW.md §Strategy: Trunk-Based Development` as a governance
constraint.

**The sole remote-write carve-out is the spec pipeline's.** `spec-pr-opener` is
the only push-capable agent: it may push to a branch named `spec/NNN-slug` and
open a **draft** PR, only after every configured quality gate is green, per
`docs/SPEC_PIPELINE.md §Commit and push carve-out`.

## Model-Assignment Discipline


## ADR Requirement

