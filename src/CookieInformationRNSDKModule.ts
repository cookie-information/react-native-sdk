import { NativeModule, requireNativeModule } from 'expo';

/**
 * Consent choices keyed by purpose/category.
 * iOS uses ConsentItemType raw values: "necessary", "marketing", "statistical", "functional", "custom".
 * Android uses consent item titles (localized). Custom purposes and other keys may appear.
 */
interface TrackingConsents {
  necessary?: boolean;
  marketing?: boolean;
  statistical?: boolean;
  functional?: boolean;
  custom?: boolean;
  [key: string]: boolean | undefined;
}

/** Consent item shape (id, universalId, title, description, required, type, accepted). Returned by getSavedConsents/cacheConsentSolution; pass to saveConsents. */
export interface ConsentItem {
  id: number;
  universalId: string;
  title: string;
  description: string;
  required: boolean;
  type: string;
  accepted: boolean;
}

interface AcceptAllConsentsResponse {
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

interface CacheConsentSolutionResponse {
  consentItems: ConsentItem[];
  /** Consent solution version ID (iOS only). */
  consentSolutionVersionId?: string;
}

/**
 * Confirmation returned when consent was successfully saved to the server.
 */
export interface SaveConsentsResponse {
  success: true;
  /** Number of consent items that were saved. */
  savedCount: number;
}

declare class CookieInformationRNSDKModule extends NativeModule {
  /**
   * Initialize the native SDKs.
   * This must be called before any other SDK method.
   */
  initialize(options: InitializeOptions): Promise<void>;
  /**
   * Show the privacy pop-up so the user can view and change consent choices.
   * Typically used from settings or a "Privacy preferences" entry point.
   * Resolves with the user's consent choices after they close the dialog.
   */
  showPrivacyPopUp(): Promise<TrackingConsents>;
  /**
   * Show the privacy pop-up only if the user has not yet consented or the consent
   * solution version has changed. Use at app start or when re-checking is needed.
   * @param options - Optional: ignoreVersionChanges (iOS), userId (Android).
   */
  showPrivacyPopUpIfNeeded(
    options?: { ignoreVersionChanges?: boolean; userId?: string | null }
  ): Promise<TrackingConsents>;
  acceptAllConsents(userId?: string): Promise<AcceptAllConsentsResponse>;
  /**
   * Remove all stored consents from the device. Data on Cookie Information servers is not deleted.
   * @param userId - (Android) Optional user id; omit for anonymous user.
   */
  removeStoredConsents(userId?: string | null): Promise<void>;
  /**
   * Fetch the consent solution from the server. On Android, also saves it to the local database.
   * Returns the consent items (from the fetched solution on iOS, from local DB after cache on Android).
   * iOS also returns the consent solution version ID.
   * Note: On iOS the SDK does not persist the fetched solution to local storage; only the returned
   * items are available in memory. Use getSavedConsents after the user has submitted choices (e.g. via
   * the consent dialog) to read persisted data on iOS.
   */
  cacheConsentSolution(): Promise<CacheConsentSolutionResponse>;
  /**
   * Retry sending any failed consent uploads.
   */
  synchronizeIfNeeded(): Promise<void>;
  /**
   * Read consent items from local storage.
   * - Android: Returns items from the local DB (cached solution + user choices). May have items
   *   after cacheConsentSolution even before the user selects anything.
   * - iOS: Returns only consents that were saved when the user submitted choices (e.g. via the
   *   consent dialog or saveConsents). Empty until the user has completed the flow at least once.
   * @param userId - (Android) Optional user id; omit for anonymous user. Ignored on iOS.
   */
  getSavedConsents(userId?: string | null): Promise<CacheConsentSolutionResponse>;
  /**
   * Send consent to the server manually. Pass the list of consent items (e.g. from getSavedConsents).
   * Solution id is taken from native config; mapping into SDK structures is done in native code.
   * On iOS, the consent solution version is normally taken from cacheConsentSolution.
   * You may pass consentSolutionVersionId to override that value (iOS only).
   * Saves consent items to the local database and sends them to the server on both platforms.
   * @param consentItems - List of consent items to save (id, universalId, accepted, etc.).
   * @param customData - Optional custom data (e.g. email, device_id).
   * @param userId - (Android) Optional user id; omit for anonymous user. Ignored on iOS.
   * @param consentSolutionVersionId - (iOS) Optional version id override when already known.
   */
  saveConsents(
    consentItems: ConsentItem[],
    customData?: Record<string, string> | null,
    userId?: string | null,
    consentSolutionVersionId?: string | null
  ): Promise<SaveConsentsResponse>;
}

const native = requireNativeModule<CookieInformationRNSDKModule>(
  'CookieInformationRNSDK',
);

export default {
  initialize: (options: InitializeOptions) => native.initialize(options),
  showPrivacyPopUp: native.showPrivacyPopUp.bind(native),
  showPrivacyPopUpIfNeeded: (
    options?: { ignoreVersionChanges?: boolean; userId?: string | null }
  ) => native.showPrivacyPopUpIfNeeded(options ?? {}),
  acceptAllConsents: native.acceptAllConsents.bind(native),
  removeStoredConsents: (userId?: string | null) =>
    native.removeStoredConsents(userId ?? null),
  cacheConsentSolution: native.cacheConsentSolution.bind(native),
  synchronizeIfNeeded: native.synchronizeIfNeeded.bind(native),
  getSavedConsents: (userId?: string | null) =>
    native.getSavedConsents(userId ?? null),
  saveConsents: (
    consentItems: ConsentItem[],
    customData?: Record<string, string> | null,
    userId?: string | null,
    consentSolutionVersionId?: string | null
  ) =>
    native.saveConsents(
      consentItems,
      customData ?? null,
      userId ?? null,
      consentSolutionVersionId ?? null
    ),
};