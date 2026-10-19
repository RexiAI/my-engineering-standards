# AC-031: Orchestration and model-env compliance

## AC-031-56 — check-orchestration.sh passes
Given the spec-deployer agent file and all wiring are in place
When `scripts/check-orchestration.sh` is run
Then it exits 0 — every agent reference (including `spec-deployer`) resolves to a file under `agents/`, and every script path cited in the new agent resolves

## AC-031-57 — check-model-env.sh passes
Given the `opencode.json` and `config/model.local.env.example` updates are in place
When `scripts/check-model-env.sh` is run
Then it exits 0 — every `agent.*.model` entry (including `spec-deployer`) is an `{env:SPEC_*_MODEL}` reference with no literal model id, and `config/model.local.env.example` defines exactly the referenced vars

## AC-031-58 — check-audit-trail.sh selftest still passes
Given the `scripts/check-audit-trail.sh` extension for `40-deploy.md` is in place
When `scripts/check-audit-trail.sh --selftest` is run
Then it exits 0 — all existing selftest scenarios (AC-015-07 through AC-015-16) still pass, and any new selftest scenarios for the `40-deploy.md` check also pass

## AC-031-59 — check-no-hardcoded-secrets.sh passes
Given all wiring changes are in place
When `scripts/check-no-hardcoded-secrets.sh` is run
Then it exits 0 — no credential values appear in any tracked file under the scanned directories

## AC-031-60 — guard-env.sh passes
Given no new tracked env files have been added
When `scripts/guard-env.sh` is run
Then it exits 0 — `config/agent.local.env` is not in the tracked set
