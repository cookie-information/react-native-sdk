# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-06-03

### Breaking changes

- Removed Expo-based integration from the SDK. Use bare React Native only.
- `expo` is no longer a peer dependency.
- Peer dependency `react-native` is now `>=0.79.0 <0.87.0`.
- **Android `initialize()`** no longer fetches or caches the consent solution on init. For custom UI, call `cacheConsentSolution` after `initialize` (matches iOS behavior and documentation).
- **Android promise error codes** renamed to align with iOS. Update any code that checks `error.code` on Android:
  - `SDK_NOT_INITIALIZED` → `INIT_ERROR`
  - `SDK_INIT_ERROR` → `INVALID_INIT`
  - `CONSENT_ERROR` → `UI_ERROR`, `FETCH_ERROR`, or `SAVE_ERROR` (depending on the failing operation)
- **Android `acceptAllConsents`** no longer clears stored user data before saving. Call `removeStoredConsents` first if you need a reset before accepting all.
- **TypeScript API — consent item methods:**
  - `cacheConsentSolution()` now returns `Promise<ConsentItem[]>` instead of `{ consentItems, consentSolutionVersionId? }`. Use the array directly; `consentSolutionVersionId` is no longer returned from this method.
  - `getSavedConsents()` return type is explicitly `Promise<ConsentItem[]>` with full item metadata (`id`, `universalId`, `title`, `description`, `required`, `type`, `accepted`).
  - `saveConsents()` no longer accepts `consentSolutionVersionId`. The response includes a `consents` array in addition to `savedCount`.
  - `TrackingConsents`, `AcceptAllConsentsResponse`, and related types are exported for typed integrations.

### Added

- Native unit tests: iOS (Swift Testing) and Android (Kotest), with CI jobs (`test:ios`, `test:android`).
- `ConsentMapping` extracted as a shared Android mapping module.

### Changed

- SDK integration follows the standard React Native native-module setup.
- Example app uses a bare React Native CLI workflow. Bundle ID `com.cookieinformation.rnsdk.example` (replaces legacy Expo `expo.modules.*` identifier).
- Peer dependencies target React 19.x.
- Native SDK dependencies: `mobileconsents` 3.1.0, `core` 1.0.0, iOS `MobileConsentsSDK` 1.5.8.
- Android library module: `compileSdkVersion` 36, `targetSdkVersion` 35; `react-android` pinned as `compileOnly`.
- Example and dev dependencies: `react` 19.2.x, `ts-jest` 29.4.11, and related TypeScript/Babel tooling updates.
- Android privacy pop-up flow: fixed `Flow.first()` usage so the built-in UI resolves correctly.
- README: documents `cacheConsentSolution` requirement for custom UI, `acceptAllConsents` behavior, and updated integration steps.

### Migration

- Remove `expo` from your app if it was added only for this SDK.
- Use React Native 0.79.x or newer (below 0.87), then reinstall dependencies and relink native modules. On iOS, run `pod install`.
- Follow the updated integration steps in `README.md`.
- **Custom UI on Android:** after `initialize()`, call `cacheConsentSolution()` before building UI or calling `saveConsents`.
- **Error handling on Android:** replace legacy error codes with the iOS-aligned codes listed above.
- **Accept all on Android:** if you relied on implicit data reset before `acceptAllConsents`, call `removeStoredConsents()` explicitly first.
- **Custom UI / TypeScript:** replace `const { consentItems } = await cacheConsentSolution()` with `const consentItems = await cacheConsentSolution()`. Remove any use of `consentSolutionVersionId` when calling `saveConsents`.

## [1.0.0] - 2026-02-10

### Added

- Initial public release of the project.
