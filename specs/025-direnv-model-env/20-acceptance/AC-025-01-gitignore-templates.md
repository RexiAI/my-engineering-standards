# AC-025-01: `.envrc` gitignored per-machine; committed dotenv templates

## AC-025-01-01 — Root `.envrc` is untracked and gitignored
Given the repo root contains a `.envrc` on disk (per-machine, may hold secrets)
And the root `.gitignore` contains a line matching `^\.envrc$`
When git is asked `git ls-files --error-unmatch -- .envrc`
Then the exit code is non-zero (the file is not tracked)
And `git check-ignore -- .envrc` exits 0

## AC-025-01-02 — `templates/.envrc.example` exists, tracked, three dotenv lines in order
Given the committed file `templates/.envrc.example`
When the file's executable (non-comment, non-blank) lines are read
Then there are exactly three lines, in this order:
And line 1 is `dotenv_if_exists config/model.local.env.example`
And line 2 is `dotenv_if_exists config/model.local.env`
And line 3 is `dotenv_if_exists config/agent.local.env`
And the file contains no `eval`, no `bash ` invocation, no `source`, no `. ` and no `--emit`
And `git ls-files --error-unmatch -- templates/.envrc.example` exits 0

## AC-025-01-03 — `templates/.envrc.child` exists, tracked, three dotenv lines in order
Given the committed file `templates/.envrc.child`
When the file's executable (non-comment, non-blank) lines are read
Then there are exactly three lines, in this order:
And line 1 is `dotenv_if_exists .standards/config/model.local.env.example`
And line 2 is `dotenv_if_exists config/model.local.env`
And line 3 is `dotenv_if_exists config/agent.local.env`
And the file contains no `eval`, no `bash ` invocation, no `source`, no `. ` and no `--emit`
And `git ls-files --error-unmatch -- templates/.envrc.child` exits 0

## AC-025-01-04 — No committed `.envrc` outside `templates/`
Given the git index of the standards repo
When `git ls-files` is filtered for paths matching `.envrc`
Then the only results are `templates/.envrc.example` and `templates/.envrc.child`

## AC-025-01-05 — Real env files stay ignored; examples stay committable
Given the repo's `.gitignore` rules
When `git check-ignore` is run for `config/model.local.env` and `config/agent.local.env`
Then the exit code is 0 for both (real per-machine files are ignored)
And when `git check-ignore` is run for `config/model.local.env.example` and `config/agent.local.env.example`
Then the exit code is non-zero for both (committed templates stay trackable)

## AC-025-01-06 — Both templates document one-time setup and per-line roles
Given `templates/.envrc.example` and `templates/.envrc.child`
When their headers are read
Then each documents `direnv allow` as part of one-time setup
And each names the three files it loads and their roles (committed defaults, per-machine override, credentials)
And each states the `.envrc` is per-machine and never committed
