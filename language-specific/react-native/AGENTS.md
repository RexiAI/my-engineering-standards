# React Native Standards

This is the entry point for the React Native stack. Repo-wide rules (conventional commits, layered testing, secrets handling) are inherited from the root `AGENTS.md` and are not restated here.

## Project Shape

- **Entry point**: Expo managed workflow via `create-expo-app`. Bare React Native is an escape hatch for narrow native needs — see `NATIVE.md` — and is not a co-equal supported path.
- **Navigation**: Expo Router (file-based, app/ directory).
- **Language**: TypeScript, `strict: true` in `tsconfig.json` extending the shared `tsconfig.base.json`.
- **JS engine**: Hermes. JSC is not used.
- **Architecture**: New architecture (Fabric, TurboModules, Bridgeless) is required. The old architecture is not a supported path.

## Always-Rules

- **No Node-only APIs in app code.** No `fs`, no `path`, no `Buffer` for app data, no `process.env` for runtime config. Use `expo-file-system`, `expo-constants`, or `expo-env` instead.
- **Tokens and secrets go in `expo-secure-store`.** `AsyncStorage` is never used for secrets.
- **TypeScript discipline.** No `// @ts-ignore`. `@ts-expect-error` is allowed only with a reason comment on the same line.
- **Platform-specific code** lives in `.ios.tsx` / `.android.tsx` files or uses `Platform.select`. No `if (Platform.OS === 'ios')` branching in shared business logic.
- **Server state**: TanStack Query. **Client state**: Zustand. Other state libraries only under a "when to consider" framing in `PATTERNS.md`.
- **Unit and component tests**: React Native Testing Library. **E2E tests**: Maestro.
- **Build / release**: EAS Build, EAS Submit, EAS Update.

## Read in Order

1. [`PATTERNS.md`](./PATTERNS.md) — state, navigation, forms, styling, performance, platform-specific code.
2. [`NATIVE.md`](./NATIVE.md) — prebuild, signing, dropping to native code, when to stay managed.
3. [`TESTING.md`](./TESTING.md) — RNTL, Maestro, Detox upgrade path, what to mock.

## Adoption

Child repos opt in by adding `language-specific/react-native/AGENTS.md` to their `opencode.json` `instructions` array, alongside any other language-specific guides they use.
