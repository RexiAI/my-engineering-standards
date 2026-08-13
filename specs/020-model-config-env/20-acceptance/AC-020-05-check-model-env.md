# AC-020-05: `scripts/check-model-env.sh` gate proves AC-001, AC-006, and the fallback source is wired

## AC-020-05-01 — A literal model id in opencode.json fails the check
Given an `opencode.json` whose `agent.spec-coder.model` is the literal `opencode-go/deepseek-v4-flash` (not an env reference)
When `scripts/check-model-env.sh` runs against it
Then it exits 1
And its output names the offending agent (`spec-coder`)

## AC-020-05-02 — All env references pass the check
Given an `opencode.json` where all 8 `agent.*.model` values are `{env:SPEC_*_MODEL}` references
And `config/model.local.env` is not tracked by git
And `config/model.local.env.example` exists defining exactly the 8 referenced vars
When `scripts/check-model-env.sh` runs against it
Then it exits 0
And prints a PASS line

## AC-020-05-03 — A tracked real env file fails the check (CI mode)
Given a scratch git repo where `config/model.local.env` is tracked (committed)
When `scripts/check-model-env.sh` runs against that repo (with `GIT_DIR`/`--git-dir` pointing at it)
Then it exits 1
And its output names the offending path `config/model.local.env`

## AC-020-05-04 — A reference with no example default fails the check (fallback source not wired)
Given an `opencode.json` whose `agent.spec-coder.model` is `{env:SPEC_CODER_MODEL}`
And a `config/model.local.env.example` that does not define `SPEC_CODER_MODEL` (all other 7 vars present)
When `scripts/check-model-env.sh` runs against it
Then it exits 1
And its output names `SPEC_CODER_MODEL` (the reference with no fallback default)

## AC-020-05-05 — An example var with no reference fails the check (wiring mismatch)
Given a `config/model.local.env.example` defining `SPEC_UNUSED_MODEL=opencode-go/something` in addition to the 8 referenced vars
When `scripts/check-model-env.sh` runs against it
Then it exits 1
And its output names `SPEC_UNUSED_MODEL` (the example var with no reference)
