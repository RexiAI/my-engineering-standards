# AC-022-04: self-CI gates stay green, no CRLF, orchestration refs resolve

## AC-022-04-01 — make lint exits 0
Given the changed files from this spec
When `make lint` is run from the repo root
Then it exits 0

## AC-022-04-02 — make validate-all exits 0
Given the changed files from this spec
When `make validate-all` is run from the repo root
Then it exits 0
And every `docs/[A-Z_]+.md` reference in the changed doc text resolves to an existing file

## AC-022-04-03 — check-orchestration.sh exits 0
Given the changed files from this spec
When `scripts/check-orchestration.sh` is run
Then it exits 0

## AC-022-04-04 — check-skills.sh exits 0
Given the changed files from this spec
When `scripts/check-skills.sh` is run
Then it exits 0

## AC-022-04-05 — init-ci.sh still parses after all edits
Given the script `scripts/init-ci.sh`
When `bash -n scripts/init-ci.sh` is run
Then it exits 0

## AC-022-04-06 — No CRLF, and the diff is scoped to this spec's paths
Given the changed files from this spec
When each is scanned for a CRLF byte
Then none contains `$'\r$'`
And `git status` shows changes only under `docs/CI_CD.md`, `scripts/init-ci.sh`, and `specs/022-child-repos-semantic-release/`
