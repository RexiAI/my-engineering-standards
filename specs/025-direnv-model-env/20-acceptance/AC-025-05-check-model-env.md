# AC-025-05: `check-model-env.sh` — no literal model id, both real env files untracked, example wired

## AC-025-05-01 — Real repo passes with a PASS line
Given the standards repo with `scripts/check-model-env.sh` and its real `opencode.json`
When `bash scripts/check-model-env.sh` runs against the repo root
Then the exit code is 0
And the output contains a `PASS` line

## AC-025-05-02 — Literal model id in `opencode.json` fails, naming the agent
Given a fixture git repo whose `opencode.json` sets `spec-coder.model` to a literal provider/model id
When `bash scripts/check-model-env.sh` runs against the fixture root
Then the exit code is 1
And the output names `spec-coder` as the offending agent

## AC-025-05-03 — Tracked `config/model.local.env` fails, naming the path
Given a fixture git repo with `config/model.local.env` committed to the index
When `bash scripts/check-model-env.sh` runs against the fixture root
Then the exit code is 1
And the output names `config/model.local.env`

## AC-025-05-04 — Tracked `config/agent.local.env` fails, naming the path
Given a fixture git repo with `config/agent.local.env` committed to the index
When `bash scripts/check-model-env.sh` runs against the fixture root
Then the exit code is 1
And the output names `config/agent.local.env`

## AC-025-05-05 — A reference with no example default fails, naming the var
Given a fixture repo whose example omits `SPEC_CODER_MODEL` while `opencode.json` references it
When `bash scripts/check-model-env.sh` runs against the fixture root
Then the exit code is 1
And the output names `SPEC_CODER_MODEL`

## AC-025-05-06 — An example var with no reference fails, naming the var
Given a fixture repo whose example adds `SPEC_UNUSED_MODEL` with no `{env:SPEC_UNUSED_MODEL}` reference in `opencode.json`
When `bash scripts/check-model-env.sh` runs against the fixture root
Then the exit code is 1
And the output names `SPEC_UNUSED_MODEL`

## AC-025-05-07 — Clean fixture passes
Given a fixture git repo with an `opencode.json` of exactly the 8 `{env:SPEC_*_MODEL}` references, an example defining exactly those 8 vars, and neither real env file tracked
When `bash scripts/check-model-env.sh` runs against the fixture root
Then the exit code is 0
And the output contains a `PASS` line
