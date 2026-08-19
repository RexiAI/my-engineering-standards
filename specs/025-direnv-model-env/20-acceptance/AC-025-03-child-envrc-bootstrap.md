# AC-025-03: Child `.envrc` — parent committed defaults, child override, bootstrap wiring

Hermetic cases emulate direnv's `dotenv_if_exists` as
`[ -f <path> ] && set -a && . <path> && set +a`, run from a child fixture root.

## AC-025-03-01 — No child files: all 8 vars resolve to the parent's committed defaults
Given a child fixture root containing a `.standards/config/model.local.env.example` that defines all 8 SPEC_*_MODEL vars at differentiated values (plus tier → plus value, fast tier → fast value)
And no child `config/model.local.env`, no child `config/agent.local.env`
When the three child template lines are emulated in order from the child fixture root
Then all 8 SPEC_*_MODEL vars are exported
And `SPEC_VERIFIER_MODEL`, `SPEC_MUTATION_RUNNER_MODEL`, `SPEC_PR_OPENER_MODEL` equal the parent fixture's plus value
And `SPEC_CODER_MODEL`, `SPEC_SPECIFIER_MODEL`, `SPEC_UX_MODEL`, `SPEC_REFACTORER_MODEL`, `SPEC_PIPELINE_MODEL` equal the parent fixture's fast value
And no var is empty and the emulation exits 0

## AC-025-03-02 — Child override wins; the parent's other defaults stay
Given a child fixture root with the parent's committed example in `.standards/config/`
And a child `config/model.local.env` defining `SPEC_CODER_MODEL=<child-value>`
When the three child template lines are emulated in order
Then `SPEC_CODER_MODEL` equals `<child-value>`
And the other 7 vars keep the parent's committed defaults
And the emulation exits 0

## AC-025-03-03 — Parent per-machine overrides never propagate to children
Given the standards repo's git index lists neither `config/model.local.env` nor `config/agent.local.env`
And a child fixture whose `.standards/` checkout therefore contains only the committed `.example` files
When the three child template lines are emulated in order
Then the `.standards/`-relative line resolves against the committed example only
And all 8 vars still resolve to the parent's committed defaults
And no error is raised for the absent parent real files

## AC-025-03-04 — Child credentials load from the child's own `config/agent.local.env`
Given a child fixture root with the parent's committed example in `.standards/config/`
And a child `config/agent.local.env` defining `GITHUB_TOKEN=<t>` and `GH_TOKEN=<g>`
When the three child template lines are emulated in order
Then `GITHUB_TOKEN` equals `<t>` and `GH_TOKEN` equals `<g>`
And the values come from the child's file, not from `.standards/`

## AC-025-03-05 — bootstrap.sh writes the child `.envrc` and gitignore wiring
Given a scratch child repo with `.standards/` present and no `.envrc`
When `./.standards/scripts/bootstrap.sh` runs
Then `<child>/.envrc` is created as a copy of `templates/.envrc.child`
And the child's root `.gitignore` contains a line matching `^\.envrc$`
And a child `config/.gitignore` exists containing `model.local.env` and `agent.local.env`
And the printed next-steps `git add` list does not name `.envrc`
And given the bootstrap runs again on a child that now has `.envrc`
Then bootstrap prints a skip message and does not overwrite the existing `.envrc`

## AC-025-03-06 — Live: a bootstrapped child defaults to parent defaults, override wins (direnv-conditional)
Given direnv installed
And a scratch child repo built by `bootstrap.sh` with `direnv allow` run
When `direnv exec <child> bash -c 'printf %s "${SPEC_VERIFIER_MODEL:-EMPTY}"'` runs with no child override file
Then the output equals the real parent's committed default for spec-verifier
And when a child `config/model.local.env` overriding `SPEC_VERIFIER_MODEL=<child-value>` is added and `direnv allow` re-run
Then the output equals `<child-value>`
And the case skips with PASS-noted status when the `direnv` binary is absent
