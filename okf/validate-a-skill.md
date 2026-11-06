---
type: runbook
title: Validate a Skill (Cook-First)
description: Runbook for the second-session rule — proving a skill works on new inputs before trusting it, with the trial protocol and the recording table
tags: [skills, validation, cook-first, second-session, authoring]
timestamp: 2026-11-05T00:00:00Z
---

# Validate a Skill

`scripts/check-skills.sh` proves a skill is well-formed. It cannot prove the
skill works. This runbook is the behavioral half: the method, the trial
protocol, and where the evidence goes.

The standard lives in `docs/AGENTS_AND_SKILLS.md §Behavioral Validation`. This
file is the operating procedure.

## When to run this

- A skill was just written from a session (Cook-First distill step).
- A skill is about to be cited as authority in an agent, a command, or a
  pipeline stage.
- A skill has been used for a while and nobody remembers correcting the agent.
  (That is either perfection or neglect — a second session tells you which.)

## Protocol

1. **Pick the skill.** Prefer one that a real event triggers on its own
   (`ci-triage` fires on a red PR, `pr-review-triage` fires on a review
   round) over one you have to simulate.
2. **Do not re-read the skill first.** Load it and run the task. Reading it to
   decide whether it "looks right" is level 0 evidence — none.
3. **Make the task different.** Another repository, another error class,
   another PR shape. Same inputs re-test the transcript, not the skill.
4. **Count corrections, not vibes.** Every time you have to correct the agent,
   write it down: what it did, what it should have done. That number is the
   measurement.
5. **Fix the recipe.** Move each correction into `SKILL.md` (or a
   `references/` file). A fix applied only to the output recurs next run.
6. **Record it** in the skill's `# Validation` table and in the trial table
   below.

## Pass / fail

| Outcome | Rule |
|---|---|
| **Pass** | Second run needs fewer corrections than the first, and no correction repeats one already fixed |
| **Fail — narrow** | The same correction recurs → the note was not promoted into the body, or it is written as prose the agent can skim past |
| **Fail — wrong recipe** | The skill encodes one session's inputs (a client name, one project layout) → generalise the steps or move the specifics to `references/` |
| **Fail — not a skill** | The task only worked because you steered it in the moment → it was never a repeatable recipe; delete it rather than carry dead instructions |

A fail is a result, not a reason to weaken the rule. If two real sessions both
need the same correction every time, the task may not be skill-shaped.

## Levels

Do not skip level 1 to reach an eval. Full table:
`docs/AGENTS_AND_SKILLS.md §Behavioral Validation`.

## Trial record

Active trial, opened 2026-11-05. Two skills chosen because a real event
triggers them without simulation. Fill one row per real second-session run;
close the trial when each skill has two.

| Skill | Run | Date | Task / inputs (different from first use) | Corrections needed | Recipe change made |
|---|---|---|---|---|---|
| `ci-triage` | first-use baseline | | | | |
| `ci-triage` | level 1 | | | | |
| `pr-review-triage` | first-use baseline | | | | |
| `pr-review-triage` | level 1 | | | | |

**Decision at close:** if corrections do not drop, demote the skill to
advisory reference (or delete it) and record why. If they drop, the rule earns
its place and the pattern is reused for the next skill.

## What this runbook is not

- Not a CI gate. There is no script for "did the recipe generalise"; claiming
  one exists is the error the standard warns about.
- Not a licence to keep unvalidated skills. An unvalidated skill is a
  hypothesis in the instructions path: either validate it or stop citing it.
