# Loop State

KILL SWITCH: off

Values for the `KILL SWITCH:` line: `off` (run normally) or `on` (do not start
this run). Every loop checks this line at the start of each run.

## High Priority

- [ ] `.github/workflows/daily-triage.yml` provides no `GH_TOKEN`/`GITHUB_TOKEN`
  to the "Run daily triage loop" step, so every `gh` call the skill mandates
  (label check, PR list, CI runs, issue create) fails as configured. The
  2026-08-20-064701 run recovered the job token from actions/checkout's
  persisted git credentials to complete pre-flight and triage. Human decision:
  wire `GH_TOKEN: ${{ github.token }}` into that step explicitly, or document
  the reliance on checkout's `persist-credentials` (which a security-hardening
  pass could disable, silently breaking the kill-switch label check).

## Watch List

- [ ] None this run. (Zero open PRs; no `specs/` directory on `main`; no open
  issues.)

## Recent Noise

- [ ] RESOLVED 2026-08-20: two self-ci failures on
  `fix/reusable-workflows-top-level` (2026-08-19T18:11Z, runs 32285901783 /
  32285931672) were superseded by green runs on the same branch
  (2026-08-19T18:19–18:20Z); `main` green at 2026-08-19T18:22:58Z.
- [ ] RESOLVED 2026-08-20: one cancelled self-ci run on
  `spec/023-pr-review-agent` (2026-08-19T16:40:18Z) superseded by a success on
  the same branch at the same minute; not a failure.

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
