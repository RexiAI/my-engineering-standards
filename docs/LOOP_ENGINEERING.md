# Loop Engineering

A loop is an automated agent cycle with durable state: a scheduled agent that
runs against a repo, tracks its own progress in state files, and (at higher
readiness levels) proposes changes to tracked code. This document is the
foundation for designing, running, and retiring loops safely.

## Primitives

Five primitives plus durable memory make up every loop:

- **Scheduling** — a cadence (cron, on-demand trigger) that decides when the loop
  runs. Scheduling is what turns a one-shot agent invocation into a loop.
- **Worktrees** — isolated working directories per loop, so a running loop never
  writes into the working tree of an interactive session or another loop.
- **Skills** — packaged, versioned capabilities the loop loads at run time.
- **MCP connectors** — access to external tools (issue trackers, repos, docs).
  These run least-privilege (see [§ Safety](#safety)).
- **Sub-agent maker/checker split** — a loop delegates work to a maker sub-agent
  that produces output and a separate checker sub-agent that verifies it; the
  same agent never both produces and approves.
- **Durable state** — `STATE.md` and `loop-run-log.md`, the loop's memory across
  runs. Without durable state every run starts blind and the loop is not really a
  loop.

## Readiness levels

A loop's level describes how much it may do unattended:

- **L0 Draft** — pattern sketched; runs only by hand on the author's machine; no
  schedule, no state files, no unattended changes.
- **L1 Report** — loop runs on a schedule and writes only its own state files
  (`STATE.md`, `loop-run-log.md`); it makes no changes to tracked code or infra.
  A new pattern never skips L1 on a production repo.
- **L2 Assisted** — loop may propose changes, but every change requires human
  sign-off before it lands (no unattended edits, no auto-merge).
- **L3 Unattended** — loop runs with no human in the loop; merging any pull
  request it produces is still a human action.

The rule is unconditional:

```text
A new pattern never skips L1 on a production repo.
```

## Loop design checklist

Every loop is designed against ten items before it runs unattended:

1. **Purpose/scope** — what the loop does and, just as importantly, what it
   explicitly does not do.
2. **Scheduling** — cadence and trigger; who can start a run.
3. **Skills** — which skills the loop loads, and which it must not.
4. **Maker/checker** — the split: who produces, who verifies.
5. **State** — which state files the loop reads and writes.
6. **Human handoff** — where and how results reach a human.
7. **Connectors** — which MCP connectors are attached, at what permission.
8. **Cost** — token budget and sub-agent spawn budget per run.
9. **Observability** — run-log, metrics, and how a stuck run is noticed.
10. **Safety** — denylist, human gates, kill switch.

## Slow, pause, kill

- **Slow** a loop when it is within budget but consuming more than expected
  (token spend trending up, run duration rising). Reduce cadence or scope before
  it becomes a problem.
- **Pause** a loop when it is behaving oddly but has not caused harm: stop the
  schedule, keep state intact, investigate.
- **Kill** a loop when it has caused harm, escaped its constraints, or its cost
  is out of control. A killed loop is not restarted; it is re-designed.

Kill checklist:

- kill switch set in `STATE.md`
- run-log entry written
- schedule paused
- human notified

## Incident response

When a loop misbehaves:

1. **Detect** — from run-log anomalies, budget overruns, or unexpected diffs.
2. **Stop the loop** — pause the schedule and set the kill switch.
3. **Preserve the run-log and state** — do not delete or edit them until the
   incident is classified.
4. **Notify the human owner** — the person responsible for the loop.
5. **Classify** — what went wrong and at which boundary (skills, connectors,
   constraints, state).
6. **Remediate** — fix the cause.
7. **Add a constraint** to `loop-constraints.md`, or a checklist item, so the
   same incident does not recur.

## Safety

Loops must never touch paths on the denylist:

```text
.env*, **/secrets/**, auth/**, payments/**, k8s/production/**, migrations/**
```

A denied path is still editable with human approval — the denylist gates
unattended edits, not all edits.

Loops never auto-merge:

```text
Loops never auto-merge. Merging a loop's pull request is always a human action.
```

MCP connectors run least-privilege: read + comment, never merge. If a connector
does not need a capability, it is not granted.

Human gates are always required for:

- security and auth changes
- payments
- infrastructure
- dependency upgrades
- any change larger than the per-loop file-count threshold `N` (default 10)
- a third failed attempt on the same item

The kill switch lives as a flag in `STATE.md` that every loop checks at the
start of each run; a loop whose kill switch is `on` does not start.
