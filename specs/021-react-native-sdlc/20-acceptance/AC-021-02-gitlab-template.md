# AC-021-02: GitLab template for React Native defines the RN hidden jobs, no docker

## AC-021-02-01 — File exists, parses as YAML, and keeps the standard node setup scaffolding
Given the file `ci/gitlab/frontend/ci-react-native.yml`
When it is parsed as YAML
Then parsing succeeds
And it defines `.node-variables` with `NODE_VERSION` set to `"22"`
And it defines `.node-cache` with key `${CI_COMMIT_REF_SLUG}` and paths including `node_modules/`
And it defines `.node-setup` with image `node:${NODE_VERSION}` and `before_script` running `npm ci`

## AC-021-02-02 — .react-native-unit hidden job runs the npm test fallback chain
Given the file `ci/gitlab/frontend/ci-react-native.yml`
When the `.react-native-unit` hidden job is inspected
Then it extends both `.node-setup` and `.node-cache`
And its script runs `npm test -- --passWithNoTests 2>/dev/null || npm test`

## AC-021-02-03 — .react-native-lint hidden job runs eslint and prettier checks
Given the file `ci/gitlab/frontend/ci-react-native.yml`
When the `.react-native-lint` hidden job is inspected
Then it extends both `.node-setup` and `.node-cache`
And its script runs `npm run lint --if-present`
And its script runs `npm run format:check --if-present`

## AC-021-02-04 — .react-native-typecheck hidden job runs tsc --noEmit
Given the file `ci/gitlab/frontend/ci-react-native.yml`
When the `.react-native-typecheck` hidden job is inspected
Then it extends both `.node-setup` and `.node-cache`
And its script runs exactly `npx tsc --noEmit`

## AC-021-02-05 — .react-native-build hidden job exports the bundle
Given the file `ci/gitlab/frontend/ci-react-native.yml`
When the `.react-native-build` hidden job is inspected
Then it extends both `.node-setup` and `.node-cache`
And its script runs exactly `npx expo export`

## AC-021-02-06 — .react-native-eas hidden job runs only on the default branch when EXPO_TOKEN is present
Given the file `ci/gitlab/frontend/ci-react-native.yml`
When the `.react-native-eas` hidden job is inspected
Then it extends both `.node-setup` and `.node-cache`
And its `rules` gate on `$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH`
And its `rules` gate on `$EXPO_TOKEN != null`
And its script runs `npx eas-cli build --non-interactive`

## AC-021-02-07 — No .react-native-docker hidden job exists
Given the file `ci/gitlab/frontend/ci-react-native.yml`
When its hidden job definitions are enumerated
Then there is no `.react-native-docker` job
