---
name: react-native
description: React Native standards: Expo managed workflow, TypeScript strict, Hermes, new architecture; NATIVE.md / PATTERNS.md / TESTING.md pointers; no Node-only APIs in app code. Use whenever a child repo uses React Native.
license: See repo root
applyTo: "**/{app,src}/**/*.{ts,tsx,js,jsx}, **/app.json, **/eas.json"
---

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
- **Platform-specific code** lives in `.ios.tsx` / `.android.tsx` files or uses `Platform.select`. No `if (Platform.OS === 'ios')` branching in shared business logic. See `reactnative.dev/docs/platform-specific-code` — `Platform.select` for small style differences inside `StyleSheet.create`, file extensions for larger divergences (same doc §Platform-specific extensions). Expo blog `expo.dev/blog/expo-app-folder-structure-best-practices` §Platform-specific code endorses identical props across `bar-chart.tsx` + `bar-chart.web.tsx`.
- **Styling:** `StyleSheet.create` + JS design tokens (`theme/tokens.ts`: `spacing`, `palettes`, `typography`, `radius`), not CSS files. Follow `reactnative.dev/docs/stylesheet` Code quality tips: move styles away from render into `StyleSheet.create` at the bottom of the file, name styles for reuse, rely on static type checking; per `expo.dev/blog/expo-app-folder-structure-best-practices` §Colocate your styles, keep `StyleSheet.create` at bottom of same file or extract to `styles.ts` / `Component.styles.ts` when the block grows — both are valid. Enforce `StyleSheet.create` + token imports via `eslint-plugin-react-native` (`no-inline-styles`, `no-color-literals`, `sort-styles`). Property order (Layout→Box→Typography→Visual→Animation) applies inside `StyleSheet.create` objects, same as web `docs/CODING_CONVENTIONS.md §CSS — Clean Code`. No literal `style={{ padding: 16 }}`; allow only `style={[styles.x, { color: theme.text }]}` array merges for dynamic theme values.
- **File organization:** one component per file and one component per directory still apply — `components/Foo/Foo.tsx` + `components/Foo/styles.ts` + `components/Foo/index.ts` (barrel), not flat `components/chat/` with 7 components in one directory. `docs/CODING_CONVENTIONS.md §File Organization` and `§React Native Styling` apply together.
- **Server state**: TanStack Query. **Client state**: Zustand. Other state libraries only under a "when to consider" framing in `PATTERNS.md`.
- **Unit and component tests**: React Native Testing Library. **E2E tests**: Maestro.
- **Build / release**: EAS Build, EAS Submit, EAS Update.

## Read in Order

1. [`PATTERNS.md`](./PATTERNS.md) — state, navigation, forms, styling, performance, platform-specific code.
2. [`NATIVE.md`](./NATIVE.md) — prebuild, signing, dropping to native code, when to stay managed.
3. [`TESTING.md`](./TESTING.md) — RNTL, Maestro, Detox upgrade path, what to mock.

## Adoption

Child repos opt in by adding `language-specific/react-native/SKILL.md` to their `opencode.json` `instructions` array, alongside any other language-specific guides they use.
