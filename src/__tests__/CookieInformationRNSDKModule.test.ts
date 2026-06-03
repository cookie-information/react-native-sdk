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

const platformSelect = jest.fn(
  (spec: { ios?: string; default?: string }) => spec.default ?? ''
);

jest.mock('react-native', () => ({
  NativeModules: {
    CookieInformationRNSDK: mockNative,
  },
  Platform: {
    select: platformSelect,
  },
}));

import MobileConsent from '../CookieInformationRNSDKModule';

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
    const items = [
      {
        id: 1,
        universalId: 'u',
        title: 't',
        description: 'd',
        required: false,
        type: 'custom',
        accepted: true,
      },
    ];
    MobileConsent.saveConsents(items);
    expect(mockNative.saveConsents).toHaveBeenCalledWith(items, null, null);
  });

  describe('when native module is not linked', () => {
    it('throws a readable linking error when a method is called', () => {
      jest.resetModules();
      jest.doMock('react-native', () => ({
        NativeModules: {},
        Platform: {
          select: (spec: { ios?: string; default?: string }) =>
            spec.default ?? '',
        },
      }));

      const MobileConsentUnlinked =
        require('../CookieInformationRNSDKModule').default;

      expect(() =>
        MobileConsentUnlinked.initialize({
          clientId: 'client',
          clientSecret: 'secret',
          solutionId: 'solution',
        })
      ).toThrow("doesn't seem to be linked");
    });
  });
});
