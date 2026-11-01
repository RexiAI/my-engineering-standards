# AC-040-04: Docs, tests and gates consistent

## AC-040-04-01 — MEDIA_AGENTS.md documents opt-in
Given `docs/MEDIA_AGENTS.md`
When read
Then every agent path is under `agents-optional/`
And it states media agents are not loaded by default in child repos and names the opt-in paths

## AC-040-04-02 — No stale agents/media paths in docs
Given `docs/` excluding `docs/changes/` and `docs/adr/0007-*`
When grepped for `agents/media-`
Then there are no matches

## AC-040-04-03 — Orchestration and skills gates green
Given the repository after the change
When `scripts/check-orchestration.sh` and `scripts/check-skills.sh` run
Then both exit 0

## AC-040-04-04 — Media bats suite green
Given `scripts/tests/media-agents.bats` updated to `agents-optional/`
When it runs
Then all tests pass
