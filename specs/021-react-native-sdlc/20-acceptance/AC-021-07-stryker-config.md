# AC-021-07: Stryker config for React Native uses the Jest runner and handles the jest-expo preset

## AC-021-07-01 — File exists and parses as JSON
Given the file `ci/templates/stryker.react-native.conf.json`
When it is parsed as JSON
Then parsing succeeds with exit 0

## AC-021-07-02 — The test runner is jest, not vitest
Given the file `ci/templates/stryker.react-native.conf.json`
When its `testRunner` value is read
Then it equals `"jest"`
And the existing `ci/templates/stryker.conf.json` still has `testRunner` `"vitest"` (the two configs remain distinct)

## AC-021-07-03 — Mutate patterns cover TS and TSX components and exclude tests
Given the file `ci/templates/stryker.react-native.conf.json`
When its `mutate` patterns are read
Then they include `src/**/*.ts`
And they include `src/**/*.tsx`
And they exclude `*.test.ts(x)`, `*.spec.ts(x)`, and `*.d.ts` files

## AC-021-07-04 — Thresholds are set to the standard break level
Given the file `ci/templates/stryker.react-native.conf.json`
When its `thresholds` are read
Then `low` is `80`
And `break` is `80`

## AC-021-07-05 — The jest-expo preset is explicitly handled
Given the file `ci/templates/stryker.react-native.conf.json`
When its content is searched
Then it mentions `jest-expo` (via a `jest` block carrying the preset or a comment requiring it)

## AC-021-07-06 — docs/TESTING.md cites the RN Stryker config
Given the file `docs/TESTING.md`
When its Mutation Testing section is read
Then it references `ci/templates/stryker.react-native.conf.json` as the React Native Stryker config
