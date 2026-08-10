# React Native — Patterns

Day-to-day app code patterns. This is the deep material the
[`AGENTS.md`](./AGENTS.md) index points to. Update rules, project shape,
and CI gates live in the index; this file is for how to use the stack.

## State

The split is non-negotiable. Pick by data source, not by convenience.

| Kind of state | Default | Notes |
|---|---|---|
| Server state (anything fetched, paginated, cacheable, refetchable) | **TanStack Query** (`@tanstack/react-query`) | Owns cache, retries, dedup, background refetch. |
| Client state (UI flags, draft form, ephemeral preferences) | **Zustand** | Tiny store, no provider tree, no boilerplate. |

TanStack Query and Zustand do not overlap; do not put server data in
Zustand.

### When to consider alternatives

- **React Context** for one-off, very rarely changing values (theme,
  auth session handed down from a top-level wrapper). Not a Zustand
  replacement.
- **MMKV** for non-secret, large, synchronous, on-device data the
  Query cache cannot own (recent searches, draft content). Treat as a
  last resort — it bypasses the cache invalidation story.
- **Redux Toolkit** only when migrating an existing Redux app. New
  projects: do not adopt.

## Navigation

Built on Expo Router (file-based, in the `app/` directory).

- Routes are files. `app/settings/index.tsx` → `/settings`. Dynamic
  segments use `[id]`. Layouts are nested folders with their own
  `layout.tsx`.
- Stack, tabs, and drawers are `Stack`, `Tabs`, `Drawer` from
  `expo-router`. Wrap the root layout in one of them.
- Links use `<Link href="…">` for typed, prefetching navigation.
  `useRouter()` is for imperative pushes/replaces.
- The route group's `(group)` directory is for shared layouts without
  affecting the URL — `(auth)/login.tsx` resolves to `/login`.
- Search params are typed via the `Route` helper and accessed with
  `useLocalSearchParams()` / `useGlobalSearchParams()`.
- Deep links and universal links are declared in `app.json` under
  `scheme` and `ios.infoPlist.associatedDomains`.

## Forms

- One form = one component, one submit handler, one `onSubmit(values)`
  call. No inline business logic in the JSX.
- Use `react-hook-form` for non-trivial forms (> 3 fields, dynamic
  fields, async validation). Pair with `zod` for schema validation:
  `zodResolver(schema)` in the `useForm` config.
- Plain `useState` is fine for one or two fields (login, opt-in toggle).
  Don't reach for `react-hook-form` for those.
- Submit on the form's `onSubmit`, not on a button `onPress`. A button
  inside a form triggers the form's submit; this keeps keyboard
  "Done/Go" working.
- Show server errors next to the field they apply to, not in a single
  top-of-form banner. The top banner is for transport failures only.
- Disable the submit button while a submission is in flight; never
  guard with a local `isSubmitting` you set by hand. `react-hook-form`
  gives you `formState.isSubmitting`.

## Styling

- Default: `StyleSheet.create({...})` in the same file. Predictable,
  zero runtime cost.
- `NativeWind` (Tailwind for RN) is the second option when a project
  already standardizes on Tailwind across web and mobile. Do not mix
  with `StyleSheet` in the same component.
- No inline object literals in `style={{}}` for anything beyond a one-
  off dynamic value. Inline objects create new identities on every
  render and defeat memoization.
- Theme tokens (colors, spacing, radii) live in a single `theme.ts`
  module. Components import named tokens, never raw hex values.
- Animations: `react-native-reanimated` for layout and gesture work,
  `Animated` API only for trivial opacity/transform tweens. Avoid
  layout-property animations through JS.

## Performance

- **Lists**: `FlatList` for short lists, `FlashList` (from
  `@shopify/flash-list`) for anything ≥ 30 items or variable-height
  rows. Always pass `keyExtractor` and a stable `getItemType` for
  heterogeneous lists.
- **Images**: `expo-image` instead of the built-in `Image` for remote
  sources. Set `priority` on the LCP image, `placeholder` for the
  blurhash, and `contentFit` deliberately.
- **Navigation transitions**: keep them under 250 ms perceived
  duration. Profile with React DevTools Profiler; don't trust the
  release-mode feel.
- **Hermes** is the engine. Don't ship JSC. Keep Hermes on for every
  build profile; measure impact of turning it off before considering
  it.
- **Re-renders**: a component that receives a new object/array
  identity on every render is a bug. Memoize at the boundary
  (`React.memo` + stable props) or fix the upstream state shape.
- **Bundle**: import the specific file you need, not the package
  barrel. `import { X } from 'y'` for tree-shaking; the dev bundle
  hides the cost.

## Platform-Specific Code

The index rule is the surface; this section is the how.

### File extensions

Use `.ios.tsx` / `.ios.ts` and `.android.tsx` / `.android.ts`
suffixes when the implementation diverges substantially — different
layouts, different navigation, different vendor SDK calls. The bundler
resolves the right one at build time; the shared base name imports
the correct variant.

```tsx
// components/DatePicker/index.ios.tsx
export { default } from './DatePicker.ios'
```

### `Platform.select`

For small, expression-level differences (a margin, an icon, a copy
string), use `Platform.select`. The result is computed once at module
load.

```tsx
import { Platform, Text } from 'react-native'

const headline = Platform.select({
  ios: 'Tap to continue',
  android: 'Tap to continue',
  default: 'Tap to continue',
})

export const Headline = () => <Text>{headline}</Text>
```

### What to avoid

- `if (Platform.OS === 'ios')` in shared business logic (services,
  state slices, hooks). It silently makes the Android path dead code
  to TypeScript and to reviewers; it also breaks tree-shaking.
- Per-component branching on platform for layout. Reach for two
  files (`.ios.tsx` / `.android.tsx`) instead.
- Platform checks in tests. If a component is platform-specific, the
  test imports the specific file and tests one platform at a time.
