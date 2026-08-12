# AC-021-08: the self-CI gates pass on the shipped diff

## AC-021-08-01 — make lint exits 0 with the new YAML files in scope
Given the three new YAML files `.github/workflows/frontend/ci-react-native.yml`, `ci/gitlab/frontend/ci-react-native.yml`, and `ci/templates/child-ci-react-native.yml`
When `make lint` runs from the repo root
Then it exits 0 (every `.github` and `ci` YAML file, including the three new ones, parses)

## AC-021-08-02 — make validate-all exits 0
Given the diff produced by this spec
When `make validate-all` runs from the repo root
Then it exits 0

## AC-021-08-03 — check-orchestration.sh exits 0
Given the diff produced by this spec
When `scripts/check-orchestration.sh` runs from the repo root
Then it exits 0

## AC-021-08-04 — check-skills.sh exits 0
Given the diff produced by this spec
When `scripts/check-skills.sh` runs from the repo root
Then it exits 0

## AC-021-08-05 — bash -n passes on the modified init-ci.sh
Given the file `scripts/init-ci.sh` as modified by this spec
When it is parsed by bash
Then `bash -n scripts/init-ci.sh` exits 0

## AC-021-08-06 — No CRLF line endings in any new or changed file
Given every file this spec adds or modifies
When each file's bytes are inspected
Then no line ends with a carriage-return byte (`grep -qU $'\r$'` returns non-zero for each file)

## AC-021-08-07 — The diff touches only the paths in scope
Given the working tree after this spec's implementation
When `git status` is inspected
Then no untracked or modified path falls outside `.github/workflows/frontend/ci-react-native.yml`, `ci/gitlab/frontend/ci-react-native.yml`, `ci/templates/child-ci-react-native.yml`, `ci/templates/stryker.react-native.conf.json`, `scripts/init-ci.sh`, `docs/CI_CD.md`, `docs/TESTING.md`, and `specs/021-react-native-sdlc/`
