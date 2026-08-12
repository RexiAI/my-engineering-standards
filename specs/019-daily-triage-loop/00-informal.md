# Daily Triage loop (report-only L1 cadence over repo state)

A low-cost loop that runs on a daily cadence, triages the repo's state (open PRs,
specs awaiting build, CI health, open questions), writes outcomes to STATE.md +
loop-run-log.md, and reports — it takes no automatic action in week one. Brings
the daily-triage pattern from cobusgreyling/loop-engineering. This is the
**L1 report-only** entry loop every new pattern must start as.

## What it must provide

1. **Schedule.** Daily (weekdays) via a scheduled GitHub Actions workflow
   (`schedule: cron`) running `opencode run` headlessly against a triage prompt,
   OR a cron/systemd `opencode run` — use the mechanism that exists in this repo.
   Durable, survives restarts; first run fires immediately.

2. **Triage skill.** `skills/loop-triage/SKILL.md` with a tight output format:
   - Open PRs needing action (failing CI, changes requested, ready to merge).
   - Specs under `specs/` awaiting `/build` or stuck at a gate.
   - CI health from self-ci; any red on a feature branch.
   - Open questions from the last run still unresolved.
   - Anything ambiguous → surface to human, never guess.

3. **State.** Read STATE.md at start, write outcomes + timestamp at end. Update
   `loop-run-log.md` (append-only JSON entry). Prune resolved items.

4. **Report-only (L1).** No auto-fix, no auto-PR in week one. Human reviews the
   report (issue or STATE.md section) and decides actions. Escalate only what
   truly needs a human.

5. **Budget + kill switch.** Daily token cap in `loop-budget.md`; kill switch
   (`loop-pause-all` label or STATE.md flag); early exit when nothing actionable.

## Acceptance criteria

- AC-001: a scheduled daily workflow exists in `.github/workflows/` (or the
  documented cron) running the triage loop.
- AC-002: `skills/loop-triage/SKILL.md` exists with the tight output format and
  the never-guess rule.
- AC-003: each run reads + writes STATE.md and appends one loop-run-log.json
  entry with the required fields.
- AC-004: the loop is report-only — no code change, no PR, no merge, in week one.
- AC-005: budget cap + kill switch documented and honored; early exit when
  nothing actionable.
- AC-006: human is notified only when action is required, not on every run.
