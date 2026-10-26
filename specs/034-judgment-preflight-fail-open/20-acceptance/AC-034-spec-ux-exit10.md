# AC-034: Task 5 — fix `agents/spec-ux.md` exit-10 contract

## AC-034-20 — exit 10 runs the stock applicability check, never BLOCKED
Given the `spec-ux` agent's applicability fast-path in `agents/spec-ux.md`
When the fast-path returns exit 10
Then the agent is instructed to run the stock applicability check
(the `# Applicability check (first action, always)` section) unchanged
And the instruction does not emit `BLOCKED` for exit 10

## AC-034-21 — `ambiguous` answer still blocks
Given the `spec-ux` agent's applicability fast-path
When the fast-path returns exit 0 with answer `ambiguous`
Then the agent emits `BLOCKED — <one question>`
And `BLOCKED` is not emitted for any other fast-path outcome

## AC-034-22 — `run` and `skip` answers are unchanged
Given the `spec-ux` agent's applicability fast-path
When the fast-path returns exit 0 with answer `run`
Then the agent loads the design skill and proceeds
When the fast-path returns exit 0 with answer `skip`
Then the agent emits the existing `SKIPPED — …` line and ends its turn

## AC-034-23 — spec-ux telemetry records `fallback:true` plus a reason
Given the `spec-ux` agent's applicability fast-path returns exit 10
When the agent records its judgment telemetry
Then the line includes `"fallback":true`
And the line includes a `"reason"` field whose value is one of
`unconfigured`, `unreachable`, `payload_overflow`, `error`
And the agent no longer claims the payload is sent untruncated
