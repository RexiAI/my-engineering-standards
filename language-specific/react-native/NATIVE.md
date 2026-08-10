# React Native — Native Layer

Dropping down to iOS and Android, the managed-workflow escape hatches,
and the rules that decide when to use them. The default is still
managed Expo — this file is for the cases where the default isn't
enough.

## When to Read This

You probably don't need to read this. The managed workflow covers
push notifications, deep links, file system, sensors, secure storage,
in-app purchases, splash screens, and most third-party SDKs. If your
feature has a maintained Expo equivalent, use it and skip the rest of
this file.

Read on if you need a vendor SDK without a JS bridge, custom native
UI, or a build hook the managed workflow doesn't expose.

## Prebuild

`npx expo prebuild` generates the `ios/` and `android/` directories
from the configuration in `app.json` / `app.config.js`. After
prebuild, you can edit native code; subsequent prebuilds will warn
about overwritten changes.

- Run prebuild once on a clean tree, then commit the generated
  native directories if you intend to maintain them. Otherwise, run
  prebuild as a CI step and never commit the output.
- Re-run prebuild when bumping Expo SDK versions, changing
  `app.json` plugin configuration, or adding a plugin.
- Do not run prebuild locally on a machine with uncommitted native
  changes — it will overwrite them.

## Signing

iOS and Android signing are different lifecycles; treat them
separately.

**iOS.** EAS Build expects either a `credentials.json` managed via
`eas credentials` (the default, recommended path) or an explicit
distribution certificate + provisioning profile pair. Apple Developer
enrollment is per-team. Ad-hoc / TestFlight / App Store Connect flows
are configured in `eas.json` per profile.

**Android.** EAS Build expects either an upload keystore managed by
EAS (`eas credentials`, default) or an explicit `*.jks` / `*.keystore`
file. The upload key is separate from the app-signing key Google
Play uses after the first upload; keep both backed up.

**Never commit** `.jks`, `.keystore`, `google-services.json`, or
`GoogleService-Info.plist` to the repository. Add them to
`.gitignore` (see `templates/.gitignore.expo`).

## When *Not* to Eject

Ejecting is a one-way door. The cases that *seem* to require it
usually have a managed-workflow answer:

| Looks like it needs eject | Managed answer |
|---|---|
| Custom native UIView / UIViewController | A Expo module wrapping the view, or a community module |
| Direct camera / sensor access | `expo-camera`, `expo-sensors`, `expo-location` |
| Background work | `expo-task-manager` + `expo-background-fetch` |
| Custom notification payload shape | `expo-notifications` extension point |
| Vendor SDK without an Expo module | `expo-modules-autolinking` + a thin Expo module wrapper |

If after that exercise you still need bare RN, see *Bare RN Escape
Hatch* below.

## Bare RN Escape Hatch

A short subsection, deliberately. Bare React Native is a tool for
narrow native integration, not a co-equal supported path. The Expo
managed workflow remains the entry point; the org's CI templates,
OTA channel, and asset pipeline are all wired to it.

If a project has ejected:

- Pin the Expo SDK version and the React Native version explicitly in
  `package.json`. Don't drift.
- Keep `expo-modules-autolinking` so any future Expo module
  additions Just Work.
- Treat the `ios/` and `android/` directories as first-party source
  code (review, format, lint, test). They are no longer "generated".
- Re-evaluate yearly. A new Expo module release often makes the
  reason for ejecting obsolete.

## Swift / Kotlin Style

Do not invent Swift or Kotlin style rules here. The platforms
themselves publish authoritative guides; follow them.

- **Swift**: [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/),
  [Apple's SwiftLint guidance](https://github.com/realm/SwiftLint),
  and the per-feature Apple documentation.
- **Kotlin**: [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)
  and the [Android Kotlin style guide](https://developer.android.com/kotlin/style-guide).

## App Store / Play Store Publishing

Publishing is a project-level workflow, not a per-commit policy. This
file does not contain a publishing tutorial; the platform owners
publish authoritative, current guides.

- **App Store**: [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
  and [Submitting apps to the App Store](https://developer.apple.com/documentation/submit-app).
- **Google Play**: [Google Play Console Help](https://support.google.com/googleplay/android-developer)
  and [Launch on Google Play](https://developer.android.com/distribute/console).

EAS Submit automates the upload portion of both; the metadata,
screenshots, and review-response workflow stay in App Store Connect
and the Google Play Console.
