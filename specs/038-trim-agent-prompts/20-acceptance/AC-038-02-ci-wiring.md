# AC-038-02: CI wiring

## AC-038-02-01 — self-ci runs the line-cap check
Given `.github/workflows/self-ci.yml`
When its steps are read
Then one step runs `./scripts/check-agent-line-cap.sh`

## AC-038-02-02 — AGENTS.md documents the check
Given `AGENTS.md`
When searched for `check-agent-line-cap.sh`
Then at least one match exists
