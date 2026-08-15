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

### Agent-to-tier mapping

Each agent's tier is its highest granted action class as read from its permission frontmatter.
T3 prohibitions apply to all agents regardless of tier.

| Agent | Stage | Trust tier | Frontmatter basis (real) | Policy override (if any) |
|---|---|---|---|---|
| `spec-verifier` | 4 | **T0** | edit only `specs/*/25-verification.md` (`*: deny`); `git commit*`/`git push*` denied | none — reads, runs gates, writes only its report |
| `spec-specifier` | 1 | **T1** | edit `specs/**` allow, `*` deny; `git *` allow | none |
| `spec-coder` | 2 | **T1** | read denies only `00-informal.md`; `git push*` denied, other git allowed | prose says never commit/push — frontmatter would allow `git commit` |
| `spec-refactorer` | 3 | **T1** | read denies `specs/**`; `git push*` denied, other git allowed | prose says never commit/push — frontmatter would allow `git commit` |
| `spec-mutation-runner` | 5a | **T1** | read denies `00-informal.md`; `git commit*`/`git push*` denied | none — edits tests/report, no git write |
| `spec-pr-opener` | 5b | **T2** | read denies `00-informal.md`; `git push*` is `ask`; git commit allowed | none — the only push-capable agent |
| `spec-ux` | 1.5 | **T2 (frontmatter) / T1 (policy)** | read `*` allow; `git commit*` ask, `git push*` ask | prose says "Do not commit or push" — frontmatter permits push only on human confirmation |
| `spec-pipeline` | orchestrator | **T1 (policy)** | no `permission` block at all — opencode primary defaults grant full access | policy (its instructions) forbids commit/push; frontmatter imposes no restriction |

No agent is mapped to T3: T3 is the universal prohibition, not an assignment.

## Model-Assignment Discipline

Model assignments for the spec pipeline live in exactly one authoritative
place: `opencode.json`, under the `agent.<name>.model` key. `opencode.json` is
the single authoritative source of which model runs each pipeline stage.

The `AGENTS.md` model table (`AGENTS.md §OpenCode Go Model Configuration`) is a
**mirror** of that source, for humans and for the model-fallback plugin's
documentation. It is not a second source of truth: only its fallback-chain
column carries information `opencode.json` does not, and that column must not be
edited to reflect a primary model change without the `opencode.json` change
landing in the same commit.

**Same-commit rule:** change a model only by editing `opencode.json` **and** the
`AGENTS.md` mirror table in the same commit. Never edit one without the other.

**Frontmatter rule:** agent files must not pin a `model:` key (per
`docs/SPEC_PIPELINE.md §Model configuration` — a pinned `.md` model silently overrides
`opencode.json`). If a child repo pins a model in frontmatter anyway,
that edit must land in the same commit as the mirror table edit.

**Conformance note:** violating the same-commit rule is a governance defect — a
review blocker, same class as the ADR rule. The drift observed in this repo (a
model entry pointing at a nonexistent agent, `spec-architect`) is exactly what
this rule exists to prevent.

## ADR Requirement

