# AC-040-02: Explicit opt-in

## AC-040-02-01 — Global installer sources relocated files
Given `scripts/media/install.mjs` run with a temporary global dir
When it installs
Then the four media agent files are copied from `agents-optional/` into `<global>/agents/`

## AC-040-02-02 — Uninstall removes them
Given the media agents installed in a temporary global dir
When `install.mjs --uninstall` runs
Then no `media-*.md` remains in `<global>/agents/`

## AC-040-02-03 — Capability catalog keeps the opt-in flag
Given `scripts/capabilities.tsv`
When the `media-agents` row is read
Then its flag column is `--with-media`

## AC-040-02-04 — Bootstrap without flag places no media agent
Given a child repo bootstrapped without `--with-media`
When its `.opencode/` tree is searched
Then no `media-*.md` file and no media agent entry exists
