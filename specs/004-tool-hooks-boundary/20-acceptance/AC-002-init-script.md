# AC-002: `init-ci.sh --with-hooks` wires hooks for child repos

## AC-002-01 — `--help` documents the flag
Given `scripts/init-ci.sh`
When the script is run with `--help`
Then it mentions `--with-hooks`

## AC-002-02 — Flag installs hooks on a clean child repo
Given a child repo without `agents/hooks/`
When `scripts/init-ci.sh --with-hooks` is run on it
Then the child repo's `agents/hooks/` is populated from this repo
And `git config core.hooksPath agents/hooks` is set

## AC-002-03 — Flag aborts on conflict with existing pre-push
Given a child repo with `.git/hooks/pre-push` already configured
When `scripts/init-ci.sh --with-hooks` is run on it
Then the flag aborts with one-line instructions
And no files are copied and no `core.hooksPath` is changed
