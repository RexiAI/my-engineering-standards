# AC-025-06: `model-env.selftest.sh` + `model-env.runtime-check.sh` reworked to the dotenv design

## AC-025-06-01 — Selftest passes on the real repo
Given the standards repo
When `bash scripts/model-env.selftest.sh` runs
Then the exit code is 0 and the summary reports 0 failed

## AC-025-06-02 — Every `AC-025-*` scenario ID is cited by a test
Given the selftest, the runtime-check, and the CI-wiring assertions
When the union of cited scenario IDs is collected
Then every ID in the `AC-025-01-*` … `AC-025-07-*` ranges appears at least once

## AC-025-06-03 — Selftest asserts parent dotenv order, override, and clobber hermetically
Given the selftest's fixture harness (mktemp fixtures, no direnv binary required, `dotenv_if_exists` emulated as `[ -f <path> ] && set -a && . <path> && set +a`)
When the parent template lines are emulated against a fixture example
Then all 8 vars export at the fixture's differentiated defaults, none empty, exit 0
And with a fixture `config/model.local.env` overriding one var, that var equals the override and the other 7 keep defaults
And with one var pre-exported, the example's value clobbers it (later line wins)

## AC-025-06-04 — Selftest asserts child inheritance and child-override-wins hermetically
Given the selftest's fixture harness with a fixture `.standards/config/model.local.env.example` at differentiated values
When the child template lines are emulated with no child files
Then all 8 vars resolve to the fixture parent's committed defaults, exit 0
And with a child `config/model.local.env` overriding one var, the child value wins and the other 7 keep parent defaults
And with a child `config/agent.local.env`, `GITHUB_TOKEN` and `GH_TOKEN` export from the child's file

## AC-025-06-05 — Selftest asserts the structural invariants from Tasks 1/4/5
Given the selftest
When it runs its structural assertions
Then `templates/.envrc.example` and `templates/.envrc.child` each contain exactly three `dotenv_if_exists` lines in the specified order and no loader words
And `.envrc` is gitignored and untracked, and no `.envrc` is committed outside `templates/`
And no `load-env.sh`, `load-model-env.sh`, or `--emit` appears in the live surface
And `check-model-env.sh` exits 0 on the real repo, and exits 1 on fixtures with `config/model.local.env` or `config/agent.local.env` tracked

## AC-025-06-06 — Selftest asserts docs and self-ci wiring
Given the selftest's docs assertions
When they run
Then `docs/SPEC_PIPELINE.md` and `AGENTS.md` document the dotenv flow and contain no loader reference
And the self-ci `validate` job still runs `check-model-env.sh`, `model-env.selftest.sh`, and `model-env.runtime-check.sh <pinned-binary>` with no `continue-on-error` on those steps

## AC-025-06-07 — Runtime check case 1: example loaded → defaults, none empty
Given a scratch project with an `opencode.json` of the 8 `{env:SPEC_*_MODEL}` references and a fixture example at differentiated values, all 8 vars unset in the invoking shell
When `bash scripts/model-env.runtime-check.sh <pinned-binary>` runs case 1 (example loaded via the dotenv-equivalent)
Then every agent's resolved model equals its fixture example default (plus tier for verifier/mutation-runner/pr-opener, fast tier otherwise)
And no agent resolves empty

## AC-025-06-08 — Runtime check case 2: file override wins; a var no file defines keeps its pre-exported value
Given the scratch project, all 8 vars unset
And a fixture `config/model.local.env` overriding `SPEC_SPECIFIER_MODEL=<file-value>`
And `SPEC_UX_MODEL` pre-exported as `<env-value>` (a var absent from all files)
When case 2 runs
Then `spec-specifier` resolves `<file-value>` (the later dotenv line wins over the example)
And `spec-ux` resolves `<env-value>` (no file defines it, so nothing clobbers it)
And the other agents resolve their example defaults

## AC-025-06-09 — Runtime check case 3: nothing loaded → all empty
Given the scratch project with all 8 vars unset and no env file loaded
When case 3 runs
Then every agent's model resolves to null/empty
And this proves the committed example is what carries the defaults

## AC-025-06-10 — Direnv-requiring cases skip cleanly when direnv is absent
Given a CI environment without the `direnv` binary
When the selftest reaches its live `direnv exec` case
Then the case prints a PASS-noted skip
And the selftest still exits 0
