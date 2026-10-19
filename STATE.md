# Loop State

KILL SWITCH: off

Values for the `KILL SWITCH:` line: `off` (run normally) or `on` (do not start
this run). Every loop checks this line at the start of each run.

## High Priority

- [ ] PR #86 (`feat/structural-cleanliness-rules`): `DIRTY` (merge conflict
  with `main`) and zero `pull_request`-event workflow runs since creation
  (2026-10-16) — no PR-event Validate, no Review PR check; absent is never
  green. Same delivery-gap pattern as #76/`8af331a`. Human/author action:
  update the branch (resolves the conflict, re-triggers checks), then review.
- [ ] Issue #77 is still open although both fixes it escalated are merged:
  #83 (loop-state persistence, 2026-10-16T14:38:41Z) and #91 (`GH_TOKEN`
  wiring, 2026-10-19T10:01:30Z; reverses #71's `NOT_PLANNED`) — the
  kill-vs-fix decision was effectively made ("fix": schedule kept, repairs
  merged). Human owed: confirm `origin/loop-state` advanced past `1e019c5`
  after the 2026-10-19 run's push, then record the decision and close #77.
  The loop does not close its own tracker (L1).

## Watch List

- [ ] PRs #90 (`fix/dup-typed-judgment-block`) and #89
  (`fix/smoke-media-windows-bl-cmd`): all checks pass (Review PR + Validate on
  push and pull_request events), `BLOCKED` awaiting human review — ready to
  merge on approval. Required-check/approval policy unreadable by the bot
  (protection API 403), so what exactly unblocks them is a human's read.
- [ ] `OPENCODE_API_KEY` pre-flight tests non-empty, not valid (#77 item 5);
  hardening is a human decision. Key verifiably valid this run (it executed).
- [ ] #76/`8af331a` missing Self CI still awaits human confirmation it was
  CI-validated pre-merge (#77 item 4; collaborator assessed the absence as a
  delivery gap — #86's absence is a second data point for that pattern).
- [ ] Docs hygiene: `docs/changes/019-daily-triage-loop.md:400` (untouched
  since 2026-08-19) still carries `## Open questions (need a human answer
  before /build)` — Q2 (loop-state branch approach) is answered by the #83
  merge, Q1/Q3/Q4/Q5 by shipped evidence. Recording the answers, and deciding
  whether to repoint this skill's stale `specs/` scan at `docs/changes/`, is
  human/doc work, out of L1 scope.
- [ ] Stale origin branches carrying pre-archive `specs/` trees:
  `spec/023-local-llm-context-management` (informal-only, no PR, untouched
  since August), `spec/001-ollama-context`, `spec/020-021-model-config-rn-sdlc`,
  `spec/023-pr-review-agent`, `chore/archive-finished-specs`,
  `feat/archive-specs-in-pr` — revive via `/spec` or delete; human decision.

## Recent Noise

- [x] RESOLVED 2026-10-19: `daily-triage.yml` gave the loop step no
  `GH_TOKEN` (carried since the 2026-08-20 run; #71 closed `NOT_PLANNED`,
  re-escalated as #77 item 3) — #91 merged 10:01:30Z wires
  `GH_TOKEN: ${{ github.token }}` (line 106). Verified live this run: every
  `gh` call authenticated as github-actions[bot] via `GH_TOKEN`, with no
  checkout-credentials recovery workaround.
- [x] RESOLVED 2026-10-16: loop-state persistence defect — 40 consecutive
  scheduled failures (2026-08-21 → 2026-10-15, the last ending `failure`
  after posting its report; `git push origin HEAD:loop-state` rejected
  non-fast-forward every time since `1e019c5`, 2026-08-20). #83 merged
  14:38:41Z parents the state commit on `origin/loop-state` (fast-forward
  only; never `--force`, never `main`). 10-16 attempt cancelled pre-merge;
  no 10-17/10-18 runs is expected (cron `0 6 * * 1-5` is weekday-only).
  2026-10-19T12:04:35Z is the first scheduled attempt under both fixes.
- [x] PRUNED 2026-10-19: the two 2026-08-20 Recent Noise entries (superseded
  self-ci failures on `fix/reusable-workflows-top-level`; cancelled run on
  `spec/023-pr-review-agent`) — older than 30 days, never carried forever.
- [x] PRUNED 2026-10-19: `loop-run-log.md` entry `2026-08-20-064701` — older
  than 30 days per §Pruning (retained in loop-state git history at `1e019c5`).

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
