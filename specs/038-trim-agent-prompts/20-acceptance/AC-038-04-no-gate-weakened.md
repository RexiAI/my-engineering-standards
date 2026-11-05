# AC-038-04: No gate removed or weakened

## AC-038-04-01 — Gate invocations preserved
Given the set of `scripts/check-*.sh` names cited in `agents/spec-*.md` on main before the change
When the same names are searched in `agents/spec-*.md` plus scripts those agents cite, after the change
Then every name is still present

## AC-038-04-02 — Thresholds unchanged
Given the diff of this change
When searched for modifications to complexity, mutation-threshold, or skill line-limit values
Then no such value changed
