# Ionic — Native Layer (Capacitor)

The native layer for Ionic apps: Capacitor project setup, workflow,
plugins, storage/secrets, and publishing. Cordova appears here only as
the legacy path it is. The entry point and always-rules live in
[`SKILL.md`](./SKILL.md).

## Capacitor, Not Cordova

**Capacitor** is a cross-platform native runtime built by the Ionic team
and is the official cross-platform runtime for Ionic Angular
(https://ionicframework.com/docs/angular/overview). It creates "Web
Native" apps: a native container running your web build, with a Plugin
API for Swift (iOS), Java (Android), and JavaScript (web) behind one
unified TypeScript API (https://capacitorjs.com/docs). The Ionic docs'
native page is Capacitor-first; older Cordova plugins are archived under
"Awesome Cordova Plugins" (https://ionicframework.com/docs/native).

**Cordova is legacy.** The framework docs still acknowledge Ionic can
deploy via "Capacitor (or Cordova)" (https://ionicframework.com/docs),
but nothing new is built on Cordova: no new projects, no new plugins, no
migration *to* Cordova. An existing Cordova app is a migration candidate
to Capacitor, not a supported destination.

## Ionic vs React Native at the Native Layer

Both stacks ship to the same stores; they differ in what runs natively
(see also [`SKILL.md`](./SKILL.md) §Ionic or React Native?):

| | Ionic + Capacitor | React Native |
|---|---|---|
| UI rendering | Web components in a native web view | Platform-native components |
| Native access | Capacitor plugins (unified TS API over Swift/Java/JS) | Native modules / TurboModules |
| Code sharing with web app | Direct — the app *is* the web build (`webDir`) | Separate app codebase; only non-UI logic shared |
| Web/PWA target from same codebase | First-class (https://ionicframework.com/docs) | Not a target |
| Best fit | Web/Angular teams, content/form/list apps, PWA + stores from one codebase | React teams needing native UI rendering characteristics |

Choose Ionic when reusing an existing web codebase and web-team skills
outweighs the need for native-component rendering. Choose React Native
when the UI itself must be native. Neither choice is a quality judgment;
they are different runtimes.

## Environment & Toolchain

From https://capacitorjs.com/docs/getting-started/environment-setup
(Capacitor 8 era):

- **Core**: Node.js 22+. Web/PWA targets need nothing else.
- **iOS**: macOS with Xcode (Capacitor 8 requires Xcode 26.0 minimum) and
  Xcode Command Line Tools (`xcode-select --install`). **Swift Package
  Manager is the default iOS dependency manager since Capacitor 8**;
  CocoaPods remains available via `npx cap add ios --packagemanager CocoaPods`.
- **Android**: Android Studio (Capacitor 8 requires 2025.2.1 minimum) +
  Android SDK (API 24+). Android Studio installs the required JDK.
- Officially supported targets: Android, iOS, Web (same page).

Per-machine setup belongs in the child repo's README, not in code
(root `AGENTS.md` secrets rules apply — no credentials in the repo).

## Project Structure & Workflow

Setup (https://capacitorjs.com/docs/getting-started):

```bash
npm i @capacitor/core && npm i -D @capacitor/cli
npx cap init                       # creates capacitor.config.* (appId, appName, webDir)
npm i @capacitor/android @capacitor/ios
npx cap add android && npx cap add ios
```

- `webDir` must point at the built web assets (`www` for Angular);
  `index.html` needs a `<head>` tag or plugin injection fails (same page).
- The `ios/` and `android/` directories are real native projects opened
  in Xcode / Android Studio — treat committed native changes as
  first-party source (review, lint, test).

Daily loop (https://capacitorjs.com/docs/basics/workflow):

1. Build the web app (`ng build` for Angular).
2. `npx cap sync` — copies the web bundle into both native projects and
   updates native dependencies. Run it after every web build and after
   adding/updating plugins.
3. `npx cap run ios` / `npx cap run android` — debug build on a
   device/emulator. `npx cap open ios|android` opens the native IDE
   instead.
4. Release binaries: open the native IDE, or `npx cap build` in CI for a
   signed AAB/APK/IPA (same page).

Keep `@capacitor/core`, `@capacitor/ios`, and `@capacitor/android` on the
**same version** — they are released in lockstep
(https://capacitorjs.com/docs/basics/workflow §Updating Capacitor).

## Plugins

- Core plugin APIs (Preferences, Filesystem, Camera, and the rest) are
  documented at https://capacitorjs.com/docs/apis/preferences and
  siblings under the same docs root; plugin concepts and custom plugins
  at https://capacitorjs.com/docs/plugins.
- **Apple privacy manifests**: several plugins use "required reason"
  APIs. Example: Preferences requires a `PrivacyInfo.xcprivacy` under
  `/ios/App` declaring `NSPrivacyAccessedAPICategoryUserDefaults` with
  reason `CA92.1` (https://capacitorjs.com/docs/apis/preferences
  §Apple Privacy Manifest Requirements; procedure at
  https://capacitorjs.com/docs/ios/privacy-manifest). Missing manifests
  block App Store submission — treat as a release-gate checklist item.
- **Community plugins**: the Capacitor Community org
  (https://github.com/capacitor-community/) maintains additional
  plugins/storage engines. The Ionic docs explicitly neither endorse nor
  support third-party options
  (https://ionicframework.com/docs/angular/storage) — vet them like any
  dependency (maintenance, license, native code review) before adopting.

## Storage & Secrets

The official options, and the honest gaps
(https://ionicframework.com/docs/angular/storage,
https://capacitorjs.com/docs/apis/preferences):

| Need | Official guidance |
|---|---|
| Lightweight key/value (settings, flags) | **Capacitor Preferences** — `UserDefaults`/`SharedPreferences` under the hood; falls back to `localStorage` on web; cleared on uninstall |
| High-volume relational/offline-first data | SQLite plugins (Capacitor Community SQLite, Cordova SQLite Storage listed for legacy); Preferences is explicitly *not* a local database |
| High-volume web + mobile | `indexedDB` on web behind the same service interface, SQLite on mobile |
| **Secrets (tokens, credentials, keys)** | **No first-party OSS plugin.** The core Capacitor plugin docs ship no Keychain/Keystore-backed secure storage plugin. The Preferences docs point to [Ionic Secure Storage](https://ionic.io/docs/secure-storage) (commercial, encrypted SQLite) and Capacitor Community engines |

Repo policy (fills the gap the OSS docs leave open — this is *our* rule,
not an official Ionic recommendation):

- **Preferences is never a secrets store** — `UserDefaults`/
  `SharedPreferences` are unencrypted.
- Secrets go in a Keychain/Keystore-backed solution: a vetted community
  plugin from https://github.com/capacitor-community/ or the commercial
  Ionic Secure Storage, wrapped behind an injectable `SecureStorageService`
  so the choice is swappable and mockable (see
  [`TESTING.md`](./TESTING.md)).
- This is the Ionic analogue of react-native's `expo-secure-store` rule:
  the *mechanism* differs because no first-party equivalent exists — the
  *policy* (encrypted-at-rest OS key storage only) is identical.
- Same as everywhere: no secrets in `capacitor.config.*`, no
  `process.env` at runtime, `.env` files gitignored (root `AGENTS.md`,
  [`../../docs/SECURITY.md`](../../docs/SECURITY.md)).

## Custom Native Code

The escape hatch, deliberately narrow — most needs are a plugin away
(https://capacitorjs.com/docs/basics/workflow §Open your Native IDE):

- Write a **Capacitor plugin** (Swift/Java/JS) rather than forking the
  container: https://capacitorjs.com/docs/plugins; iOS-specific custom
  code: https://capacitorjs.com/docs/ios/custom-code.
- After customizing, `ios/` and `android/` are first-party source. Run
  `npx cap sync` discipline strictly: sync copies the web bundle and
  updates plugin dependencies — it does not revert your custom native
  edits, but uncommitted native changes plus a sync are how accidents
  happen. Commit before syncing.
- Swift/Kotlin style: don't invent rules here — follow the platform
  guides (Swift API Design Guidelines, Kotlin coding conventions), same
  posture as the react-native guide takes.

## Publishing

Official guides, per target — this file is not a publishing tutorial:

- Ionic docs: iOS App Store https://ionicframework.com/docs/deployment/app-store,
  Google Play https://ionicframework.com/docs/deployment/play-store,
  PWA https://ionicframework.com/docs/deployment/progressive-web-app.
- Capacitor docs: https://capacitorjs.com/docs/ios/deploying-to-app-store
  and https://capacitorjs.com/docs/android/deploying-to-google-play.
- CI builds: `npx cap build` outputs signed AAB/APK/IPA; the Capacitor
  workflow docs suggest Fastlane or a cloud build service such as
  Appflow for automation (https://capacitorjs.com/docs/basics/workflow).
  **Appflow is commercial and optional** — a plain `cap build` + Fastlane
  pipeline on your own CI satisfies every requirement in this repo
  (https://ionicframework.com/docs, root `AGENTS.md` CI standards).
