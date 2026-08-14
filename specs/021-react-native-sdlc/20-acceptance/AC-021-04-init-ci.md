# AC-021-04: init-ci.sh detects React Native and generates the wiring on GitHub and GitLab

## AC-021-04-01 — Script parses and usage text advertises the react-native frontend option
Given the file `scripts/init-ci.sh`
When it is parsed by bash
Then `bash -n scripts/init-ci.sh` exits 0
And the usage text's `--frontend` list includes `react-native`

## AC-021-04-02 — Detection: an "expo" dependency classifies the project as react-native
Given a scratch project directory whose `package.json` contains `"expo"` as a dependency
When `scripts/init-ci.sh --platform github --frontend ''` runs non-interactively with the directory as cwd
Then detection resolves the frontend as `react-native`
And no frontend selection menu is required (non-interactive stdin does not hang)

## AC-021-04-03 — Detection ordering: an Expo app with a react dependency is react-native, not plain react
Given a scratch project directory whose `package.json` contains both `"expo"` and `"react"` as dependencies
When frontend detection runs
Then the frontend resolves as `react-native` and not `react`

## AC-021-04-04 — Detection: a bare "react-native" dependency (no "expo") still classifies as react-native
Given a scratch project directory whose `package.json` contains `"react-native"` but no `"expo"` dependency
When frontend detection runs
Then the frontend resolves as `react-native`

## AC-021-04-05 — The interactive frontend menu lists React Native (Expo)
Given the file `scripts/init-ci.sh`
When the interactive frontend `select` menu entries are read
Then one entry is `"React Native (Expo)"`

## AC-021-04-06 — GitHub generation wires the RN workflow and passes EXPO_TOKEN, no GHCR_TOKEN/docker-registry
Given `scripts/init-ci.sh --platform github --frontend react-native` run in a scratch directory
When `.github/workflows/ci.yml` is generated and parsed as YAML
Then it contains a `frontend-ci` job whose `uses` is `RexiAI/my-engineering-standards/.github/workflows/frontend/ci-react-native.yml@main`
And that job's `with` sets `node-version` to `"22"`
And that job's `secrets` sets `EXPO_TOKEN` to `${{ secrets.EXPO_TOKEN }}`
And the file contains no `GHCR_TOKEN` line
And the file contains no `docker-registry` line

## AC-021-04-07 — GitLab generation includes the RN template and extends .react-native-* jobs, no frontend-docker
Given `scripts/init-ci.sh --platform gitlab --frontend react-native` run in a scratch directory
When `.gitlab-ci.yml` is generated and parsed as YAML
Then it includes `local: .standards/ci/gitlab/frontend/ci-react-native.yml`
And it defines `frontend-unit` extending `.react-native-unit`
And it defines `frontend-lint` extending `.react-native-lint`
And it defines `frontend-typecheck` extending `.react-native-typecheck`
And it defines `frontend-build` extending `.react-native-build`
And it defines `frontend-eas` extending `.react-native-eas`
And it does not define a `frontend-docker` job

## AC-021-04-08 — Regression: non-RN frontends keep their existing generated shape
Given `scripts/init-ci.sh --platform github --frontend nextjs` run in a scratch directory
When `.github/workflows/ci.yml` is generated
Then its `frontend-ci` job's `uses` is `RexiAI/my-engineering-standards/.github/workflows/frontend/ci-nextjs.yml@main`
And it passes `docker-registry` in `with`
And it passes `GHCR_TOKEN` in `secrets`
Given `scripts/init-ci.sh --platform gitlab --frontend nextjs` run in a scratch directory
When `.gitlab-ci.yml` is generated
Then it defines a `frontend-docker` job extending `.nextjs-docker`

## AC-021-04-09 — EXPO_TOKEN is referenced by init-ci.sh for secrets collection and the GitHub summary
Given the file `scripts/init-ci.sh`
When its content is searched for the string `EXPO_TOKEN`
Then it matches at least once (secrets-collection prompt and/or GitHub secrets summary list)
