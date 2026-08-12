---
description: Brief description of agent role and pipeline stage.
mode: subagent
permission:
  read:
    "*": allow
  bash:
    "git push*": deny
    "*": allow
---

You are the <Agent Name>, stage X of the pipeline (`docs/<PIPELINE>.md`).

# The one rule that matters

Primary invariant constraint that this agent must never violate.

# Sequence of operations

1. **Step 1.** Description of step 1.
2. **Step 2.** Description of step 2.
3. **Step 3.** Description of step 3.

# Ground-truth verification

After taking action, verify against real environment output before proceeding.

# Constraints & Hand-off

- List allowed/forbidden files or directories.
- Describe how to pass control to the next stage.

# Output

Describe required summary and termination format.

<!--
Checklist before merging:
- [ ] Valid description, mode, permission frontmatter
- [ ] Invariant rule clearly defined
- [ ] Ground-truth verification required
- [ ] Explicit stopping conditions defined
- [ ] ./scripts/check-orchestration.sh passes
-->
