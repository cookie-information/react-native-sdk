const mockNative = {
  initialize: jest.fn(),
  showPrivacyPopUp: jest.fn(),
  showPrivacyPopUpIfNeeded: jest.fn(),
  acceptAllConsents: jest.fn(),
  removeStoredConsents: jest.fn(),
  cacheConsentSolution: jest.fn(),
  synchronizeIfNeeded: jest.fn(),
  getSavedConsents: jest.fn(),
  saveConsents: jest.fn(),
};

jest.mock('expo', () => ({
  NativeModule: class {},
  requireNativeModule: () => mockNative,
}));

const MobileConsent = require('../CookieInformationRNSDKModule').default;

describe('CookieInformationRNSDKModule', () => {
  beforeEach(() => {
    Object.values(mockNative).forEach((fn) => {
      if (typeof fn === 'function') {
        fn.mockClear();
      }
    });
  });

  it('passes initialize options to native', () => {
    const options = {
      clientId: 'client',
      clientSecret: 'secret',
      solutionId: 'solution',
      languageCode: 'EN',
      enableNetworkLogger: true,
    };
    MobileConsent.initialize(options);
    expect(mockNative.initialize).toHaveBeenCalledWith(options);
  });

  it('defaults showPrivacyPopUpIfNeeded options to empty object', () => {
    MobileConsent.showPrivacyPopUpIfNeeded();
    expect(mockNative.showPrivacyPopUpIfNeeded).toHaveBeenCalledWith({});
  });

  it('passes null for removeStoredConsents when userId missing', () => {
    MobileConsent.removeStoredConsents();
    expect(mockNative.removeStoredConsents).toHaveBeenCalledWith(null);
  });

  it('passes null defaults for saveConsents optional arguments', () => {
    const items = [{ id: 1, universalId: 'u', title: 't', description: 'd', required: false, type: 'custom', accepted: true }];
    MobileConsent.saveConsents(items);
    expect(mockNative.saveConsents).toHaveBeenCalledWith(items, null, null, null);
  });
});
