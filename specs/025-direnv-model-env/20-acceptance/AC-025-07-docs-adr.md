# AC-025-07: Docs and ADR describe the dotenv design

## AC-025-07-01 — SPEC_PIPELINE.md §Model configuration documents the dotenv flow
Given `docs/SPEC_PIPELINE.md` §Model configuration
When the section is read
Then it documents one-time setup (install direnv, `eval "$(direnv hook bash)"`, `direnv allow`)
And the parent `.envrc` copied from `templates/.envrc.example` with its three `dotenv_if_exists` lines (committed example → per-machine override → credentials)
And the child flow (`bootstrap.sh` writes `.envrc` from `templates/.envrc.child`; child defaults to the parent's committed defaults via `.standards/config/model.local.env.example`; the submodule never carries gitignored files; child override wins)
And the precedence rule (later `dotenv_if_exists` wins; a dotenv line clobbers a pre-exported var — accepted, the `.envrc` is the per-directory source of truth)
And the empty-var safety (the example loads first so the 8 vars are non-empty; `{env:VAR}` resolves empty when unset — no default syntax in this opencode build)
And the launch boundary (opencode must launch from a direnv-loaded shell; GUI/daemon launches surface as empty model resolution)
And restart-required-after-change for model edits
And the enforcement (check-model-env.sh as the primary gate; selftest + pinned-binary runtime-check in self-ci)
And the section contains no reference to `scripts/load-*.sh` or `--emit`

## AC-025-07-02 — AGENTS.md describes the gitignored `.envrc` mechanism
Given `AGENTS.md` (§OpenCode Go Model Configuration and per-machine agent environment notes)
When the relevant sections are read
Then they describe per-machine values arriving via the gitignored `.envrc` with `dotenv_if_exists` loading the committed `config/model.local.env.example` defaults
And they contain no reference to `scripts/load-*.sh`
And the model-table values are unchanged from before this spec

## AC-025-07-03 — README.md §Model Configuration describes the direnv flow
Given `README.md` §Model Configuration
When the section is read
Then it describes copying the template to the per-machine `.envrc`, `direnv allow`, editing the gitignored `config/model.local.env` for overrides, and restarting opencode
And it contains no reference to `scripts/load-*.sh`

## AC-025-07-04 — ADR 0001 records the dotenv decision with status Accepted
Given `docs/adr/0001-direnv-model-env.md`
When the ADR is read
Then its Status is `Accepted`
And it records the decision: pure direnv `dotenv_if_exists` (no loaders, no `--emit`), `.envrc` gitignored per-machine, committed templates (`templates/.envrc.example`, `templates/.envrc.child`) as the default wiring, precedence with later-lines-win and accepted clobber, and the parent/child inheritance model
And it lists the rejected alternatives, including the shell-profile status quo and the loader-`--emit` design this spec replaces
And it records compliance: check-model-env.sh, model-env.selftest.sh, model-env.runtime-check.sh

## AC-025-07-05 — ADR index reflects the updated status
Given `docs/adr/README.md`
When the index table is read
Then it lists ADR 0001 with status `Accepted`
