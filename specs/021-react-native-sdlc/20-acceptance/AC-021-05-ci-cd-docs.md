# AC-021-05: docs/CI_CD.md documents the React Native job table, divergences, tree entry, and EXPO_TOKEN

## AC-021-05-01 — React Native language section lists every step with its command and cadence
Given the file `docs/CI_CD.md`
When the React Native language section is read
Then it exists under Language Support
And its table contains a `unit-test` row running `npm test -- --passWithNoTests` on every push
And a `lint` row running `npm run lint && npm run format:check` on every push
And a `typecheck` row running `npx tsc --noEmit` on every push
And a `build/export` row running `npx expo export` on every push
And an `eas-build` row running `npx eas-cli build --non-interactive` on merge to main, requiring EXPO_TOKEN
And an `eas-submit` row on the release path
And an `e2e (Maestro)` row documented as optional or scheduled

## AC-021-05-02 — Mobile divergences are stated: no Docker by default, Maestro not a per-push gate
Given the file `docs/CI_CD.md`
When the React Native section is read
Then it states there is no Docker image step by default because EAS builds remotely
And it states Maestro E2E is emulator-dependent and therefore scheduled/optional, not a per-push gate
And it documents the v1 E2E hook (`.maestro/` flows run with `maestro test .maestro/`)

## AC-021-05-03 — EAS gating is documented for no-Expo-account repos
Given the file `docs/CI_CD.md`
When the React Native section is read
Then it states EAS jobs run only when `EXPO_TOKEN` is present
And it states a repo without an Expo account still gets green unit/lint/typecheck
And it states the EAS project id is committed config in `eas.json`/`app.json`, not a CI secret

## AC-021-05-04 — Architecture tree lists the new reusable workflow
Given the file `docs/CI_CD.md`
When the Architecture section's `.github/workflows/frontend/` listing is read
Then it contains `ci-react-native.yml` labeled as React Native

## AC-021-05-05 — Required Secrets table includes EXPO_TOKEN
Given the file `docs/CI_CD.md`
When the Required Secrets table is read
Then it contains an `EXPO_TOKEN` row
And that row names EAS build as its consumer

## AC-021-05-06 — No broken docs cross-references introduced
Given the React Native additions to `docs/CI_CD.md`
When every `docs/[A-Z_]+.md` reference in the new text is resolved against the repo
Then each referenced file exists
