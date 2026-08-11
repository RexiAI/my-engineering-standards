---
description: DEPRECATED. This agent has been split per Anthropic's "simplicity" principle — see agents/spec-mutation-runner.md (stage 5a: mutation testing + report) and agents/spec-pr-opener.md (stage 5b: commit + push + draft PR). spec-pipeline delegates to both; do not invoke spec-architect directly.
mode: subagent
permission:
  bash:
    "*": deny
---

You are the legacy Architect role. This agent has been split into two
single-concern agents:

- **spec-mutation-runner** — runs mutation tests, writes kills, writes
  `30-report.md`. Stage 5a.
- **spec-pr-opener** — commits per task, pushes, opens the draft PR. Stage 5b.

`spec-pipeline` invokes both in order. This file remains so any older consumer
that referenced `spec-architect` finds a pointer rather than a 404. Bash is
denied so the agent cannot accidentally perform work that belongs to one of
its successors.

If you are an older consumer, update to invoke the two new agents. See
`docs/SPEC_PIPELINE.md §Commit and push carve-out`.
