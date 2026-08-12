# React Native CI + full SDLC parity with Java / Go / Node

The language-specific stack guide for React Native already exists
(`language-specific/react-native/` — SKILL.md, NATIVE.md, PATTERNS.md, TESTING.md),
so the *language rules* are done. But the *tooling/SDLC* layer is not. Java, Go, and
Node each have a first-class CI story in this repo:

- `.github/workflows/backend/ci-{java,go,node}.yml` + `frontend/ci-{nextjs,react,angular}.yml`
- `ci/gitlab/backend/ci-{java,go,node}.yml` + `ci/gitlab/frontend/ci-{nextjs,react,angular,static}.yml`
- `ci/templates/child-ci-{java,go,node}.yml` + `Makefile.go` + `releaserc.json` + `stryker.conf.json` + `pitest-profile.xml`
- `scripts/init-ci.sh` frontend/backend detection, `init-deploy.sh`, `init-ci.sh --with-saga`
- `docs/CI_CD.md` per-language tables (unit/lint/contract/integration/deploy/docker)
- `docs/TESTING.md` framework references

React Native has **none** of the CI/CD layer: no reusable workflow, no GitLab
template, no child template, no init-ci detection, no CI_CD.md table row. The stack
guide points at EAS Build / EAS Submit / Maestro as the toolchain but nothing in this
repo ships that pipeline to a child repo. This spec completes the SDLC parity so a
React Native child repo can be bootstrapped like a Go or Node one.

## The stack the SDLC must target (from language-specific/react-native/)

- Unit/component: React Native Testing Library + jest + jest-expo preset (not plain
  Jest — native modules need the Expo preset).
- E2E: Maestro (YAML flows), Detox as upgrade path.
- Build/release: EAS Build, EAS Submit, EAS Update (managed Expo workflow).
- TypeScript strict, no Node-only APIs in app code.
- Secrets: expo-secure-store (not AsyncStorage); EAS credentials via `eas.json` /
  `credentials.json`.

## What parity means here (deliverables)

1. **GitHub reusable workflow** `.github/workflows/frontend/ci-react-native.yml` —
   jobs for unit test (jest-expo + RNTL), lint (eslint + prettier), typecheck (tsc
   --noEmit), and build/export (expo export or EAS build) — same shape/inputs as
   ci-nextjs.yml / ci-react.yml (node-version inputs, cache, workflow_call).
2. **GitLab template** `ci/gitlab/frontend/ci-react-native.yml` — same job set as
   the frontend GitLab templates, using `npx expo` / EAS CLI instead of `npm run
   build`.
3. **Child template** `ci/templates/child-ci-react-native.yml` — the one-file include
   a child repo drops in, mirroring `child-ci-node.yml`.
4. **init-ci.sh detection** — detect `"expo"` / `react-native` in package.json, add
   `react-native` to the frontend select menu, and emit the child template. EAS
   needs env vars (EXPO_TOKEN / EAS project id) — surface as CI secrets placeholders
   like GHCR_TOKEN is today.
5. **`docs/CI_CD.md`** — a React Native row/table (unit / lint / typecheck / EAS
   build / EAS submit / Maestro E2E) alongside the Go/Java/Node tables, plus the
   architecture tree entry. Note where mobile diverges: no Docker image step by
   default (EAS builds remotely), and E2E (Maestro) is emulator-dependent so it's a
   scheduled/optional job, not a per-push gate.
6. **`docs/TESTING.md`** — reference the RN testing layers (RNTL vs Maestro split) so
   the root testing doc doesn't claim "Jest" as if RN were plain Node.
7. **Mutation config** — Stryker config for RN (Stryker already supports
   `@stryker-mutator/jest-runner`; needs the jest-expo preset handled). Only if the
   existing `ci/templates/stryker.conf.json` can be reused/adapted — otherwise a
   dedicated `ci/templates/stryker.react-native.conf.json`.

## Open questions

- EAS Build requires network + an Expo account/EXPO_TOKEN; the GitHub/GitLab EAS job
  must be gated on `secrets.EXPO_TOKEN` being present, and documented as required for
  the deploy/main path only.
- Maestro E2E on CI needs an Android emulator or iOS simulator — decide the initial
  scope (skip in v1 of the template with a documented hook, vs. a `maestro cloud`
  call that needs an API key). Prefer the documented-hook path for the first cut.
- Should `init-deploy.sh` gain an EAS deploy path? Keep v1 scope to CI; note it as a
  follow-up.

## Acceptance criteria

- AC-001: `.github/workflows/frontend/ci-react-native.yml` exists and runs unit
  tests + lint + typecheck via workflow_call, mirroring ci-nextjs.yml structure.
- AC-002: `ci/gitlab/frontend/ci-react-native.yml` exists with the same job set.
- AC-003: `ci/templates/child-ci-react-native.yml` exists; `init-ci.sh` detects a
  react-native/expo package.json and generates a `.github/workflows/ci.yml` that
  includes it (both GitHub and GitLab paths).
- AC-004: `docs/CI_CD.md` documents the React Native job table + architecture tree
  entry; `docs/TESTING.md` references RNTL/Maestro.
- AC-005: all YAML validates (`make lint`), orchestration refs resolve
  (`scripts/check-orchestration.sh`), no CRLF.
- AC-006: EAS-related jobs are gated on EXPO_TOKEN presence and documented, so a
  repo without an Expo account still gets green unit/lint/typecheck.
