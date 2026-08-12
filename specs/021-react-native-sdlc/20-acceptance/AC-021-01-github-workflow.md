# AC-021-01: GitHub reusable workflow for React Native exists and mirrors ci-react.yml shape minus Docker

## AC-021-01-01 — File exists, is a valid reusable workflow, declares the standard inputs and read-only permissions
Given the file `.github/workflows/frontend/ci-react-native.yml`
When it is read and parsed as YAML
Then parsing succeeds
And it declares `on.workflow_call`
And it declares inputs `node-version` with default `"22"` and `node-version-file` with default `""`
And it declares `permissions.contents` as `read`
And it does not declare `permissions.packages`

## AC-021-01-02 — Concurrency group and cancel-in-progress mirror the sibling frontend workflows
Given the file `.github/workflows/frontend/ci-react-native.yml`
When its `concurrency` block is read
Then `group` equals `${{ github.workflow }}-${{ github.ref }}`
And `cancel-in-progress` is `true`

## AC-021-01-03 — unit-test job installs deps and runs the jest-expo test chain
Given the file `.github/workflows/frontend/ci-react-native.yml`
When the `unit-test` job is inspected
Then it runs `npm ci`
And it runs `npm test -- --passWithNoTests 2>/dev/null || npm run test:unit --if-present || npm test`
And its `actions/setup-node@v4` step passes `cache: npm` and resolves the version from `node-version-file` when set

## AC-021-01-04 — lint job runs eslint and prettier checks
Given the file `.github/workflows/frontend/ci-react-native.yml`
When the `lint` job is inspected
Then it runs `npm ci`
And it runs `npm run lint --if-present`
And it runs `npm run format:check --if-present`

## AC-021-01-05 — typecheck job runs tsc --noEmit
Given the file `.github/workflows/frontend/ci-react-native.yml`
When the `typecheck` job is inspected
Then it runs `npm ci`
And it runs exactly `npx tsc --noEmit`

## AC-021-01-06 — build job exports the bundle and depends on unit-test and lint
Given the file `.github/workflows/frontend/ci-react-native.yml`
When the `build` job is inspected
Then its `needs` list contains `unit-test` and `lint`
And it runs `npm ci`
And it runs exactly `npx expo export`

## AC-021-01-07 — eas-build job is gated on default-branch push plus EXPO_TOKEN and needs unit-test, lint, build
Given the file `.github/workflows/frontend/ci-react-native.yml`
When the `eas-build` job is inspected
Then its `needs` list contains `unit-test`, `lint`, and `build`
And its `if` condition requires `github.event_name == 'push'` and the default branch
And its `if` condition requires `secrets.EXPO_TOKEN != ''`
And it runs a command containing `eas-cli build --non-interactive`
And `secrets.EXPO_TOKEN` is declared with `required: false`

## AC-021-01-08 — No Docker path: no docker job, no GHCR_TOKEN, no docker inputs
Given the file `.github/workflows/frontend/ci-react-native.yml`
When its jobs and inputs and secrets are enumerated
Then there is no job named `docker`
And no secret named `GHCR_TOKEN`
And none of the inputs `docker-registry`, `docker-image-name`, or `deploy-on-main` exist

## AC-021-01-09 — A child without EXPO_TOKEN still gets green unit/lint/typecheck/build
Given the workflow at `.github/workflows/frontend/ci-react-native.yml`
When a child invokes it with no EXPO_TOKEN secret
Then the only gated job is `eas-build` (its `if` evaluates false)
And `unit-test`, `lint`, `typecheck`, and `build` are never gated on EXPO_TOKEN or the default branch
