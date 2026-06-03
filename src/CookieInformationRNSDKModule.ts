import { NativeModules, Platform } from 'react-native';

/** Consent category identifier (e.g. `necessary`, `marketing`). */
export type ConsentItemType =
  | 'necessary'
  | 'marketing'
  | 'statistical'
  | 'functional'
  | 'privacy policy'
  | 'custom';

/**
 * Returned by `showPrivacyPopUp` and `showPrivacyPopUpIfNeeded` when the privacy pop-up closes.
 *
 * Keys are consent category types ({@link ConsentItem.type}, e.g. `necessary`, `marketing`).
 * Values are `true` if the user accepted that category, or `false` if they declined it.
 */
export interface TrackingConsents {
  necessary?: boolean;
  marketing?: boolean;
  statistical?: boolean;
  functional?: boolean;
  custom?: boolean;
  [key: string]: boolean | undefined;
}

/**
 * One consent purpose from your Cookie Information solution (label, description, category, and acceptance state).
 *
 * Returned by `getSavedConsents`, `cacheConsentSolution`, `acceptAllConsents`, and `saveConsents`. Use these objects to render a custom consent UI or to read what the user has already chosen.
 *
 * When you call `saveConsents`, pass items from `cacheConsentSolution` or `getSavedConsents` with updated `accepted` values. The SDK uses only the consent identifier and `accepted` (other fields are ignored). Use `id` on Android and `universalId` on iOS. Call `cacheConsentSolution` before `saveConsents` on both platforms; without a prior cache, save does not succeed.
 */
export interface ConsentItem {
  id: number;
  universalId: string;
  title: string;
  description: string;
  required: boolean;
  type: ConsentItemType | (string & {});
  accepted: boolean;
}

export interface AcceptAllConsentsResponse {
  success: boolean;
  message: string;
  consents: ConsentItem[];
  count: number;
}

export interface InitializeOptions {
  clientId: string;
  clientSecret: string;
  solutionId: string;
  /** The SDK uses languageCode if provided; otherwise it uses the device locale. */
  languageCode?: string | null;
  /** iOS only. Ignored on Android. */
  enableNetworkLogger?: boolean | null;
  ui?: UiOptions | null;
}

export interface UiOptions {
  ios?: IosUiOptions | null;
  android?: AndroidUiOptions | null;
}

export interface IosUiOptions {
  /** Hex color like "#RRGGBB" or "#AARRGGBB". */
  accentColor?: string | null;
  fontSet?: FontSet | null;
}

export interface FontSet {
  largeTitle?: FontSpec | null;
  body?: FontSpec | null;
  bold?: FontSpec | null;
}

export interface FontSpec {
  /** iOS font name. If omitted, system font is used. */
  name?: string | null;
  size?: number | null;
  weight?: 'regular' | 'medium' | 'semibold' | 'bold' | null;
}

export interface AndroidUiOptions {
  lightColorScheme?: ColorScheme | null;
  darkColorScheme?: ColorScheme | null;
  typography?: Typography | null;
}

export interface ColorScheme {
  primary?: string | null;
  secondary?: string | null;
  tertiary?: string | null;
}

export interface Typography {
  bodyMedium?: TextStyle | null;
}

export interface TextStyle {
  /** Android font resource name in res/font (e.g. "inter_bold"). */
  font?: string | null;
  size?: number | null;
}

/**
 * Confirmation returned when consent was successfully saved to the server.
 */
export interface SaveConsentsResponse {
  success: boolean;
  /** Number of consent items that were saved. */
  savedCount: number;
  /** Saved consent items with full metadata. */
  consents: ConsentItem[];
}

/**
 * Public TypeScript API for the Cookie Information React Native SDK.
 *
 * See the package README for integration examples.
 */
export interface CookieInformationRNSDK {
  /**
   * Initialize the native SDKs. Call before any other method.
   *
   * Refreshes SDK setup and clears the cached consent solution template (repopulated on the next
   * `cacheConsentSolution` or built-in consent UI call). Does not clear stored user consent choices;
   * use {@link removeStoredConsents} to reset those.
   */
  initialize(options: InitializeOptions): Promise<void>;

  /**
   * Show the privacy pop-up so the user can view and change consent choices.
   * Typically used from settings or a "Privacy preferences" entry point.
   *
   * @returns The user's choices keyed by {@link ConsentItem.type} after they close the dialog.
   */
  showPrivacyPopUp(): Promise<TrackingConsents>;

  /**
   * Show the privacy pop-up only if the user has not yet consented or the consent solution version
   * has changed. Use at app start or when re-checking is needed.
   *
   * @param options.ignoreVersionChanges - iOS only. When true, skips version-based re-prompting.
   * @param options.userId - Android only. Optional user id; omit for anonymous user.
   * @returns The user's choices keyed by {@link ConsentItem.type} when a dialog was shown and completed.
   */
  showPrivacyPopUpIfNeeded(options?: {
    ignoreVersionChanges?: boolean;
    userId?: string | null;
  }): Promise<TrackingConsents>;

  /**
   * Accept all consent categories and save the result to the server and local storage.
   *
   * @param userId - Android only. Optional user id; omit or pass `null` for anonymous user. Ignored on iOS.
   */
  acceptAllConsents(userId?: string | null): Promise<AcceptAllConsentsResponse>;

  /**
   * Remove the user's saved consent choices from the device. Does not delete server-side consent records.
   *
   * @param userId - Android only. Optional user id; omit or pass `null` for anonymous user. Ignored on iOS.
   */
  removeStoredConsents(userId?: string | null): Promise<void>;

  /**
   * Fetch the latest consent solution from the server and cache it for custom UI flows.
   *
   * Returns the solution configuration (items and metadata), not the user's final accept/decline choices.
   * Call before {@link saveConsents} when building a custom UI; without a prior cache, save does not succeed on either platform.
   */
  cacheConsentSolution(): Promise<ConsentItem[]>;

  /** Retry sending any failed consent uploads to the server. */
  synchronizeIfNeeded(): Promise<void>;

  /**
   * Read consent items stored on the device.
   *
   * On Android, returns items from the local DB (cached solution + user choices). Items may exist after {@link cacheConsentSolution} even before the user selects anything.
   * On iOS, returns items only after the user saved choices (via dialog, {@link saveConsents}, or {@link acceptAllConsents});
   * empty until then.
   *
   * @param userId - Android only. Optional user id; omit or pass `null` for anonymous user. Ignored on iOS.
   */
  getSavedConsents(userId?: string | null): Promise<ConsentItem[]>;

  /**
   * Submit consent items to the server and store them locally.
   *
   * Pass items from {@link cacheConsentSolution} or {@link getSavedConsents} with updated `accepted` values.
   * The SDK uses only the identifier (`id` on Android, `universalId` on iOS) and `accepted`; other fields are ignored.
   * Call {@link cacheConsentSolution} before this method when using a custom UI.
   *
   * @param consentItems - Items to save.
   * @param customData - iOS only. Optional custom data (e.g. email, device_id). Ignored on Android.
   * @param userId - Android only. Optional user id; omit or pass `null` for anonymous user. Ignored on iOS.
   */
  saveConsents(
    consentItems: ConsentItem[],
    customData?: Record<string, string> | null,
    userId?: string | null
  ): Promise<SaveConsentsResponse>;
}

const LINKING_ERROR =
  `The package '@cookieinformation/react-native-sdk' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo managed workflow\n';

const native = NativeModules.CookieInformationRNSDK
  ? NativeModules.CookieInformationRNSDK
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

const MobileConsent: CookieInformationRNSDK = {
  initialize: (options) => native.initialize(options),
  showPrivacyPopUp: () => native.showPrivacyPopUp(),
  showPrivacyPopUpIfNeeded: (options) =>
    native.showPrivacyPopUpIfNeeded(options ?? {}),
  acceptAllConsents: (userId) => native.acceptAllConsents(userId ?? null),
  removeStoredConsents: (userId) => native.removeStoredConsents(userId ?? null),
  cacheConsentSolution: () => native.cacheConsentSolution(),
  synchronizeIfNeeded: () => native.synchronizeIfNeeded(),
  getSavedConsents: (userId) => native.getSavedConsents(userId ?? null),
  saveConsents: (consentItems, customData, userId) =>
    native.saveConsents(consentItems, customData ?? null, userId ?? null),
};

export default MobileConsent;
