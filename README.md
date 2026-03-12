# Cookie Information React Native SDK

React Native wrapper for the Cookie Information Mobile Consents SDKs.

> **Expo only** — This package is built as an [Expo module](https://docs.expo.dev/modules/overview/) and requires Expo. It does **not** support bare React Native projects that do not use Expo.

Native SDKs:
- Android: https://github.com/cookie-information/android-release
- iOS: https://github.com/cookie-information/ios-release

## Requirements

| Peer dependency | Version |
| --- | --- |
| `expo` | `~53.0.26` |
| `react-native` | `0.79.6` |
| `react` | `19.0.0` |

## Installation

```bash
npm install @cookieinformation/react-native-sdk
# or
yarn add @cookieinformation/react-native-sdk
```

After installing, rebuild the native project (Expo Go is not supported — a native build is required):

```bash
npx expo prebuild
npx expo run:ios   # or run:android
```

# Using the SDK

## Initializing

Initialize the SDK before calling any other method. You can initialize with or without UI customization.
SDK credentials can be fetched from the Cookie Information platform: https://go.cookieinformation.com/login

The SDK uses the `languageCode` you pass during initialization for all UI components and ignores the system language. If `languageCode` is not set, the SDK uses the device locale. You must ensure the selected language is configured in the Cookie Information platform and that content is provided for that language.

Recommended flow: initialize once, then call `showPrivacyPopUpIfNeeded` when needed (typically on app start).

Minimum required data for initialization:
- `clientId`
- `clientSecret`
- `solutionId`

```ts
import MobileConsent from '@cookieinformation/react-native-sdk';

await MobileConsent.initialize({
  clientId: 'YOUR_CLIENT_ID',
  clientSecret: 'YOUR_CLIENT_SECRET',
  solutionId: 'YOUR_SOLUTION_ID',
});
```

Here is an example of all the arguments and data that support the SDK:

```ts
await MobileConsent.initialize({
  clientId: 'YOUR_CLIENT_ID',
  clientSecret: 'YOUR_CLIENT_SECRET',
  solutionId: 'YOUR_SOLUTION_ID',
  languageCode: 'EN',        // optional
  enableNetworkLogger: false, // iOS only
  ui: {
    ios: {
      accentColor: '#2E5BFF',
      fontSet: {
        largeTitle: { size: 34, weight: 'bold' },
        body: { size: 14, weight: 'regular' },
        bold: { size: 14, weight: 'bold' },
      },
    },
    android: {
      lightColorScheme: {
        primary: '#FF0000',
        secondary: '#FFFF00',
        tertiary: '#FFC0CB',
      },
      darkColorScheme: {
        primary: '#00FF00',
        secondary: '#008000',
        tertiary: '#000000',
      },
      typography: {
        bodyMedium: { font: 'inter_regular', size: 14 },
      },
    },
  },
});
```

Notes:
- Android `font` is a resource name under `android/app/src/main/res/font`.
- Colors accept `#RRGGBB` or `#AARRGGBB`.
- iOS uses system fonts if `name` is omitted.

## Using built-in mobile consents UI

SDK contains built-in screens for managing consents. Please ensure you set the correct language code you expect the consents to use, and that it has been fully configured in the Cookie Information platform.

| iOS | Android |
| --- | --- |
| ![iOS screenshot](docs/screenshots/ios.png) | ![Android screenshot](docs/screenshots/android.png) |

## Privacy Pop-Up

### Standard flows

#### Presenting the privacy pop-up

To show the Privacy Pop Up screen regardless of state, use `showPrivacyPopUp` (typically used in settings to allow modification of consent). To show the Privacy Pop Up screen only when the user has not consented to the latest version, use `showPrivacyPopUpIfNeeded` (typically used at startup to present the privacy screen conditionally; see more below).

```ts
showPrivacyPopUp(): Promise<TrackingConsents>
```

```ts
const consents = await MobileConsent.showPrivacyPopUp();

// Return type: TrackingConsents (Record<string, boolean | undefined>)
// TrackingConsents is a map of consent choices keyed by purpose/category:
// - keys: necessary, functional, statistical, marketing, custom (plus any custom keys)
// - values: boolean (true/false) or undefined
// Example return shape:
// {
//   necessary: true,
//   functional: false,
//   statistical: true,
//   marketing: false,
//   custom: true
// }

if (consents.marketing) {
  // enable marketing SDKs
} else {
  // disable marketing SDKs
}
```

The above function resolves with the user’s selections (a key/value map of consent categories to booleans). Use this result to enable or disable third‑party SDKs based on consent.

### Presenting the privacy pop-up conditionally

`showPrivacyPopUpIfNeeded` is typically used to present the popup after app start (or at a point you choose). The method checks if a valid consent is already saved locally on the device and also checks if there are any updates on the Cookie Information server. If there is no consent saved or the consent version is different from the one available on the server, the popup is presented; otherwise it resolves immediately with the current consent data. Use `ignoreVersionChanges` to ignore consent version changes coming from the server (iOS only).

```ts
showPrivacyPopUpIfNeeded(
  options?: { ignoreVersionChanges?: boolean; userId?: string | null }
): Promise<TrackingConsents>
```

```ts
const consents = await MobileConsent.showPrivacyPopUpIfNeeded();

// Use the result to enable/disable SDKs
if (consents.marketing) {
  // enable marketing SDKs
} else {
  // disable marketing SDKs
}
```

With options (Android `userId`, iOS `ignoreVersionChanges`):

```ts
const consents = await MobileConsent.showPrivacyPopUpIfNeeded({
  ignoreVersionChanges: true, // iOS only
  userId: 'user_123', // optional on Android
});

// Example: read custom keys or localized titles
if (consents['Age Consent']) {
  // handle custom consent item
}
```

### Handling errors

Both `showPrivacyPopUp` and `showPrivacyPopUpIfNeeded` reject on error. If an error happens, the selection is still persisted locally and an attempt is made the next time `showPrivacyPopUpIfNeeded` or `synchronizeIfNeeded` is called.

```ts
try {
  await MobileConsent.showPrivacyPopUpIfNeeded();
} catch (e) {
  console.warn('Consent UI failed, retry later:', e);
  // You can call showPrivacyPopUpIfNeeded() again later (e.g. next app start).
}
```

## Custom view

If the default consent UI does not fit your product, you can build your own custom view. Use the methods below to fetch the consent solution and submit the user’s choices.

All methods return Promises and must be called after `initialize()`.

### initialize
Initialize the native SDKs before calling any other method.

```ts
initialize(options: InitializeOptions): Promise<void>
```

### cacheConsentSolution

Fetches the latest consent solution from the server. On iOS, it also returns `consentSolutionVersionId` which you must pass to `saveConsents` when sending consents manually. Use the returned `consentItems` to build your own UI if needed.

```ts
cacheConsentSolution(): Promise<{ consentItems: ConsentItem[]; consentSolutionVersionId?: string }>
```

```ts
const { consentItems, consentSolutionVersionId } =
  await MobileConsent.cacheConsentSolution();

// Example usage: build your own UI from consentItems
const itemsForUi = consentItems.map((item) => ({
  id: item.id,
  title: item.title,
  required: item.required,
  accepted: item.accepted,
}));
```

### saveConsents

Submits the selected consent items to the server and stores them locally. On iOS, you must pass `consentSolutionVersionId` from `cacheConsentSolution` (or a known version). On Android, `consentSolutionVersionId` is ignored.

Parameters:
- `consentItems`: List of consent items to save.
- `customData`: Optional custom data (e.g. email, device_id).
- `userId`: Android only, optional user id; omit or pass `null` for anonymous user. Ignored on iOS.
- `consentSolutionVersionId`: iOS only, optional version id override when already known.

```ts
saveConsents(
  consentItems: ConsentItem[],
  customData?: Record<string, string> | null,
  userId?: string | null,
  consentSolutionVersionId?: string | null
): Promise<SaveConsentsResponse>
```

```ts
const { consentItems, consentSolutionVersionId } =
  await MobileConsent.cacheConsentSolution();

await MobileConsent.saveConsents(
  consentItems,
  { device_id: 'example-device' },
  'user_123', // optional userId on Android
  consentSolutionVersionId
);
```

Notes:
- On iOS, `consentSolutionVersionId` is required and can be obtained from `cacheConsentSolution()` or passed explicitly.
- On Android, `consentSolutionVersionId` is ignored.
- `userId` is optional on Android; pass `null` or omit for anonymous user.

### getSavedConsents

`getSavedConsents` returns consent items stored on the device.
- Android: Returns items from the local DB (cached solution + user choices). Items may exist after `cacheConsentSolution` even before the user selects anything.
- iOS: Returns only consents that were saved when the user submitted choices (e.g. via the consent dialog or `saveConsents`). Empty until the user completes the flow at least once.

Parameters:
- `userId`: Android only, optional user id; omit or pass `null` for anonymous user. Ignored on iOS.

```ts
getSavedConsents(userId?: string | null): Promise<{ consentItems: ConsentItem[] }>
```

```ts
const { consentItems } = await MobileConsent.getSavedConsents();
// Return type: { consentItems: ConsentItem[] }
```

### acceptAllConsents
Fetches the solution and saves “accept all” consents.

Parameters:
- `userId`: Android only, optional user id; omit or pass `null` for anonymous user. Ignored on iOS.

```ts
acceptAllConsents(userId?: string | null): Promise<AcceptAllConsentsResponse>
```

### removeStoredConsents
Deletes stored consents on the device (does not delete server data).

Parameters:
- `userId`: Android only, optional user id; omit or pass `null` for anonymous user. Ignored on iOS.

```ts
removeStoredConsents(userId?: string | null): Promise<void>
```

### synchronizeIfNeeded
Retries failed consent uploads.

```ts
synchronizeIfNeeded(): Promise<void>
```

## Types (summary)

```ts
type TrackingConsents = Record<string, boolean | undefined>;

interface ConsentItem {
  id: number;
  universalId: string;
  title: string;
  description: string;
  required: boolean;
  type: string;
  accepted: boolean;
}

interface SaveConsentsResponse {
  success: true;
  savedCount: number;
}
```

## Logging

Enable network logging on iOS via `enableNetworkLogger: true` in `initialize()`.

## Running the example app

The example app lives in `example/` and requires a native build (Expo Go is not supported).

```bash
# from repo root
npm install
cd example
npm install

# generate native projects (first time or after native changes)
npx expo prebuild --clean

# run on device/simulator
npx expo run:ios
# or
npx expo run:android
```

Notes:
- Update the credentials in `example/App.tsx` before running.

## Notes

- Call `initialize()` before any other method.

## Implementation

For additional customization options within MobileConsentsSDK, please contact our support team.

If something is missing or you want to change something, let us know.

## Release automation

- GitHub Actions publish requires `NPM_TOKEN` repository secret.
- Release tags must match the `package.json` version (format `X.Y.Z`).
