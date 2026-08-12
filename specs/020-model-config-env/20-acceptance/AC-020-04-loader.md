# AC-020-04: `scripts/load-env.sh` exports every model var with env > local-file > example precedence

## AC-020-04-01 — No local file: all 8 vars exported to the example defaults
Given a scratch fixture directory with `config/model.local.env.example` defining all 8 `SPEC_*_MODEL` vars and no `config/model.local.env`
And a clean shell environment where none of the 8 vars are set
When `scripts/load-env.sh` runs against that fixture
Then all 8 `SPEC_*_MODEL` vars are exported with the example's values
And the script exits 0

## AC-020-04-02 — Partial local file: defined vars override, missing vars fall back to example defaults
Given a scratch fixture directory with `config/model.local.env` defining only `SPEC_SPECIFIER_MODEL=opencode-go/custom` and `SPEC_UX_MODEL=opencode-go/other`
And `config/model.local.env.example` defining all 8 vars at their committed defaults
When `scripts/load-env.sh` runs against that fixture
Then `SPEC_SPECIFIER_MODEL` is `opencode-go/custom` and `SPEC_UX_MODEL` is `opencode-go/other`
And the other 6 vars are exported at their example default values (none is unset or empty)

## AC-020-04-03 — Pre-existing exported variable is never clobbered
Given a shell environment where `SPEC_SPECIFIER_MODEL=opencode-go/process-env-win` is already exported
And a scratch `config/model.local.env` defining `SPEC_SPECIFIER_MODEL=opencode-go/file-value`
When `scripts/load-env.sh` runs against that fixture
Then `SPEC_SPECIFIER_MODEL` is still `opencode-go/process-env-win` (the process environment wins)

## AC-020-04-04 — A var resolvable from no source fails loudly
Given a scratch fixture directory with neither `config/model.local.env` nor `config/model.local.env.example`
And a clean shell environment where none of the 8 vars are set
When `scripts/load-env.sh` runs against that fixture
Then it exits 1
And prints to stderr a message naming at least one unresolved `SPEC_*_MODEL` var

## AC-020-04-05 — Runs from any cwd, non-interactively
Given `scripts/load-env.sh` in the repo
When it is invoked from a different working directory than the repo root, with `config/model.local.env` present in the repo
Then it still exports the vars (config paths are resolved relative to the repo root, documented in the script header)
And it produces no prompt and requires no TTY
