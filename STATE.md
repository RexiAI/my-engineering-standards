# Loop State

KILL SWITCH: off

Values for the `KILL SWITCH:` line: `off` (run normally) or `on` (do not start
this run). Every loop checks this line at the start of each run.

## High Priority

- [ ] [item the loop is currently working toward]

## Watch List

- [ ] [low-priority item, tracked but not acted on yet]

## Recent Noise

- [ ] [recently resolved item]

Resolved items are pruned each run, not carried forever.

## PR Babysitter

Per-watched-PR state for the `pr-babysitter` loop (spec 018; operating procedure
in `skills/pr-review-triage/SKILL.md`). One row per open PR; merged or closed
PRs are pruned on the run that observes them, and the prune is recorded in the
run-log.

| PR | Branch | Check summary | Last action | Outcome | Human override |
|---|---|---|---|---|---|
| — | — | — | — | — | — |

- Check summary: one entry per required check (`passing` / `failing` /
  `pending` / `absent-unknown`) plus whether the required-check policy is known.
- Last action / Outcome: the most recent loop action (triage, fix proposal,
  escalation, label, close/hand-off suggestion) and its result.
- Human override: any human decision that changed loop behavior for this PR
  (for example: skip the fix sub-agent, ignore a failing check, exempt from the
  human gate). A value of `—` means no override is recorded.
