# AC-038-01: Agent line-cap check script

## AC-038-01-01 — All files within cap pass
Given every `agents/spec-*.md` has at most 120 lines
When `scripts/check-agent-line-cap.sh` runs
Then it exits 0

## AC-038-01-02 — File at exactly 120 lines passes
Given a fixture `agents/spec-x.md` with exactly 120 lines
When the script runs against the fixture directory
Then it exits 0

## AC-038-01-03 — File at 121 lines fails with path and count
Given a fixture `agents/spec-x.md` with 121 lines
When the script runs against the fixture directory
Then it exits 1
And output contains `spec-x.md` and `121`

## AC-038-01-04 — Non-spec agents ignored
Given a fixture `agents/other.md` with 500 lines and no over-cap `spec-*.md`
When the script runs against the fixture directory
Then it exits 0
