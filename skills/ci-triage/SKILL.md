---
name: ci-triage
description: Triage a failing Self CI run on this repo — read the failing logs with gh, classify the failure as flake / regression / infra / config, and at L1 report-only escalate to a human or propose a minimal fix from an isolated worktree. Use when a Self CI run fails on a branch or PR, when the CI Sweeper workflow invokes a sweep, or when asked to diagnose why CI is red.
license: See repo root
allowed-tools: Bash(gh:*) Bash(git worktree add:*)
---

# When to use

A Self CI run failed on a branch or PR and someone — a human or the CI Sweeper
workflow (`.github/workflows/ci-sweeper.yml`) — needs it triaged. This is the
CI Sweeper loop's entry point. The loop is spec 017; its safety rules, state
files, and readiness levels come from spec 016 (`docs/LOOP_ENGINEERING.md`,
consumed by reference — do not re-specify them here).

# Invocation

The failing-log read used by this repo is the `gh` CLI (installed and
authenticated with `repo` scope): list the runs, then read the failed log.

```bash
gh run list --workflow "Self CI"
gh run view <RUN-ID> --log-failed
```

The **Self CI** workflow (`.github/workflows/self-ci.yml`) is the only CI that
runs on feature branches and PRs, and it has a single job, **Validate** — so the
failing job is `Validate` unless the run failed before the job started.

# Classification output

Every triage produces exactly one output with three parts:

1. **class** — exactly one of `flake`, `regression`, `infra`, `config`;
2. **failing job/step** — the job and step that failed (Self CI has one job,
   `Validate`, so name the failing step);
3. **evidence** — the log line, file:line, or step name that drove the
   classification. No classification without evidence.

# Decision guide

| Class | Meaning | Action |
|---|---|---|
| `flake` | Seen before, intermittent, or passed on retry with no code change | **Watch**, log, route to quarantine — never fix |
| `regression` | A code change introduced the failure; deterministic on the failing commit | Minimal fix in a worktree (see below) |
| `infra` | Runner OOM, registry down, secrets missing, or another environment failure | Escalate — not a code defect |
| `config` | Workflow syntax, wrong tool version, or a configuration error | Escalate — not a code defect |

The flake criteria: **seen before** (the same signature is already in the
quarantine ledger), **intermittent** (fails sometimes, passes other times on the
same commit), or **passed on retry with no code change** (a rerun of the same
commit was green).

# The flake rule

A flake is classified as **Watch**, never auto-fix. A flake is logged and routed
to quarantine, not fixed: append the flake signature, evidence, and first/last
seen dates to the quarantine ledger `docs/ci-flakes.md`, and consult that ledger
for "seen before" before classifying anything as a repeat.

# Infra and config are not code defects

Infrastructure failures (runner OOM, registry down, secrets missing) and
workflow-config failures (workflow syntax, missing tooling) are **not code
defects**. They are routed to escalation, never "fixed" by editing code.
