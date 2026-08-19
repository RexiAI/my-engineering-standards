# AC-025-02: Parent `.envrc` dotenv semantics — defaults, override, clobber, credentials

Hermetic cases emulate direnv's `dotenv_if_exists` as
`[ -f <path> ] && set -a && . <path> && set +a`, run from a fixture root.

## AC-025-02-01 — Example alone yields all 8 non-empty, differentiated defaults
Given a fixture root whose `config/model.local.env.example` defines all 8 SPEC_*_MODEL vars at differentiated values (plus-tier agents → plus value, fast-tier agents → fast value)
And no `config/model.local.env` and no `config/agent.local.env`
When the three parent `.envrc` lines are emulated in order from that fixture root
Then all 8 SPEC_*_MODEL vars are exported
And `SPEC_VERIFIER_MODEL`, `SPEC_MUTATION_RUNNER_MODEL`, `SPEC_PR_OPENER_MODEL` equal the fixture's plus value
And the other 5 vars equal the fixture's fast value
And no var is empty and the emulation exits 0

## AC-025-02-02 — Per-machine override beats the committed example
Given a fixture root whose example defines all 8 vars
And a fixture `config/model.local.env` defining `SPEC_SPECIFIER_MODEL=<override-value>`
When the three parent lines are emulated in order
Then `SPEC_SPECIFIER_MODEL` equals `<override-value>`
And the other 7 vars equal their example defaults
And the emulation exits 0

## AC-025-02-03 — A dotenv line clobbers a pre-exported shell var (later wins, accepted)
Given a fixture root whose example defines all 8 vars
And `SPEC_SPECIFIER_MODEL` pre-exported in the calling shell as `<pre-exported-value>`
When the three parent lines are emulated in order
Then `SPEC_SPECIFIER_MODEL` equals the example's value, not `<pre-exported-value>`
And the emulation exits 0

## AC-025-02-04 — Credentials load last from `config/agent.local.env`
Given a fixture root whose example defines all 8 vars
And a fixture `config/agent.local.env` defining `GITHUB_TOKEN=<t>` and `GH_TOKEN=<g>`
When the three parent lines are emulated in order
Then `GITHUB_TOKEN` equals `<t>` and `GH_TOKEN` equals `<g>`
And all 8 SPEC_*_MODEL vars are still exported
And the credentials lines execute after the model-var lines in the template

## AC-025-02-05 — Missing files are a no-op and never fail the shell
Given a fixture root with no `config/model.local.env` and no `config/agent.local.env`
When the three parent lines are emulated in order
Then no error is produced and the emulation exits 0
And given a fixture root with no files at all (no example either)
When the three lines are emulated again
Then the emulation exits 0 and exports nothing

## AC-025-02-06 — A stale local `.envrc` carries no loader references
Given a `.envrc` present on disk at the repo root
When the file is searched for `scripts/load-` and `--emit`
Then no match is found

## AC-025-02-07 — Live: direnv loads the vars after allow (direnv-conditional)
Given direnv installed with its shell hook wired
And `direnv allow` run at the repo root
When `direnv exec <repo-root> bash -c 'printf %s "${SPEC_SPECIFIER_MODEL:-EMPTY}"'` runs
Then the output is a non-empty model id
And the case skips with PASS-noted status when the `direnv` binary is absent
