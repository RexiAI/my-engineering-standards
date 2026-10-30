# AC-036-04: Wire the check and pass on the repo

## AC-036-04-01 — Repo passes the new check
Given the repo after Tasks 1–2
When scripts/check-agent-doc-duplication.sh runs at the repo root
Then it exits 0

## AC-036-04-02 — check-orchestration propagates failure
Given a fixture where check-agent-doc-duplication.sh would exit 1
When scripts/check-orchestration.sh runs against it
Then it exits 1

## AC-036-04-03 — check-orchestration still green on repo
Given the repo after this change
When scripts/check-orchestration.sh runs
Then it exits 0
