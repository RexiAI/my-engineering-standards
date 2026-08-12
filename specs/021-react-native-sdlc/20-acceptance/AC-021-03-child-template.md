# AC-021-03: Child drop-in template for React Native references the RN workflow with EXPO_TOKEN only

## AC-021-03-01 — File exists, parses as YAML, and declares the expected triggers
Given the file `ci/templates/child-ci-react-native.yml`
When it is parsed as YAML
Then parsing succeeds
And its `on.push.branches` includes `main`
And its `on.pull_request.branches` includes `main`
And it declares `on.workflow_dispatch`

## AC-021-03-02 — Header comments identify the generated-for and template paths
Given the file `ci/templates/child-ci-react-native.yml`
When its first comment lines are read
Then one line is `# Generated CI for React Native project`
And one line is `# Template: ci/templates/child-ci-react-native.yml`

## AC-021-03-03 — The job calls the RN reusable workflow with node-version and EXPO_TOKEN
Given the file `ci/templates/child-ci-react-native.yml`
When its job's `uses` value is read
Then it equals `RexiAI/my-engineering-standards/.github/workflows/frontend/ci-react-native.yml@main`
And `with.node-version` is `"22"`
And `secrets.EXPO_TOKEN` equals `${{ secrets.EXPO_TOKEN }}`

## AC-021-03-04 — No Docker or non-declared inputs/secrets leak into the template
Given the file `ci/templates/child-ci-react-native.yml`
When its content is searched
Then it contains no `GHCR_TOKEN`
And it contains no `docker-registry`
And it contains no `deploy-on-main`
