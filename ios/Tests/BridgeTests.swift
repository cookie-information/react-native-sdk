import Testing
@testable import CookieInformationRNSDK

private struct PromiseReject: Error {
  let code: String
  let message: String
}

private enum PromiseOutcome<T> {
  case resolved(T?)
  case rejected(PromiseReject)
}

private enum BridgeTestSupport {
  static let validInitOptions: NSDictionary = [
    "clientId": "test-client",
    "clientSecret": "test-secret",
    "solutionId": "test-solution",
  ]

  static func initializeModule(_ module: CookieInformationRNSDKModule) async throws -> Bool {
    let outcome = try await awaitPromise { resolve, reject in
      module.initialize(validInitOptions, resolver: resolve, rejecter: reject)
    }
    guard case .resolved = outcome else { return false }
    return true
  }


  private static let minimalSolutionJSON = """
  {
    "universalConsentSolutionId": "9187d0f0-9e25-469b-9125-6a63b1b22b12",
    "universalConsentSolutionVersionId": "00000000-0000-4000-8000-000000000000",
    "templateTexts": {
      "privacyCenterButton": [{"language": "EN", "text": "Read more"}],
      "rejectAllButton": [{"language": "EN", "text": "Reject all"}],
      "acceptAllButton": [{"language": "EN", "text": "Accept all"}],
      "acceptSelectedButton": [{"language": "EN", "text": "Accept selected"}],
      "savePreferencesButton": [{"language": "EN", "text": "Save"}],
      "privacyCenterTitle": [{"language": "EN", "text": "Privacy center"}],
      "privacyPreferencesTabLabel": [{"language": "EN", "text": "Preferences"}],
      "poweredByCoiLabel": [{"language": "EN", "text": "Powered by"}],
      "consentPreferencesLabel": [{"language": "EN", "text": "Consent preferences"}],
      "readMoreScreenHeader": [{"language": "EN", "text": "Privacy policy"}],
      "optionalTableSectionHeader": [{"language": "EN", "text": "Optional"}],
      "requiredTableSectionHeader": [{"language": "EN", "text": "Required"}]
    },
    "universalConsentItems": [
      {
        "universalConsentItemId": "a10853b5-85b8-4541-a9ab-fd203176bdce",
        "required": true,
        "type": "necessary",
        "translations": [
          {"language": "EN", "shortText": "Necessary cookies", "longText": "Necessary description"}
        ]
      },
      {
        "universalConsentItemId": "ef7d8f35-fc1a-4369-ada2-c00cc0eecc4b4",
        "required": false,
        "type": "marketing",
        "translations": [
          {"language": "EN", "shortText": "Marketing cookies", "longText": "Marketing long text"}
        ]
      }
    ]
  }
  """
}

private func awaitPromise<T>(
  _ call: (@escaping (T?) -> Void, @escaping (String?, String?, Error?) -> Void) -> Void
) async throws -> PromiseOutcome<T> {
  try await withCheckedThrowingContinuation { continuation in
    call(
      { value in continuation.resume(returning: .resolved(value)) },
      { code, message, _ in
        continuation.resume(
          returning: .rejected(
            PromiseReject(code: code ?? "", message: message ?? "")
          )
        )
      }
    )
  }
}

@Suite("Bridge")
struct BridgeTests {
  @Test("initialize rejects when required fields are missing")
  func initializeMissingFields() async throws {
    let module = CookieInformationRNSDKModule()
    let outcome = try await awaitPromise { resolve, reject in
      module.initialize([:] as NSDictionary, resolver: resolve, rejecter: reject)
    }
    guard case let .rejected(error) = outcome else {
      Issue.record("Expected rejection")
      return
    }
    #expect(error.code == "INVALID_INIT")
    #expect(error.message == "clientId, clientSecret, and solutionId are required")
  }

  @Test("saveConsents rejects non-object array before SDK access")
  func saveConsentsInvalidType() async throws {
    let module = CookieInformationRNSDKModule()
    let outcome = try await awaitPromise { resolve, reject in
      module.saveConsents(["not-a-dict"] as NSArray, customData: nil, userId: nil, resolver: resolve, rejecter: reject)
    }
    guard case let .rejected(error) = outcome else {
      Issue.record("Expected rejection")
      return
    }
    #expect(error.code == "INVALID_ARGS")
    #expect(error.message == "consentItems must be an array of objects")
  }

  @Test("getSavedConsents rejects when SDK is not initialized")
  func getSavedConsentsNotInitialized() async throws {
    let module = CookieInformationRNSDKModule()
    let outcome = try await awaitPromise { resolve, reject in
      module.getSavedConsents(nil, resolver: resolve, rejecter: reject)
    }
    guard case let .rejected(error) = outcome else {
      Issue.record("Expected rejection")
      return
    }
    #expect(error.code == "INIT_ERROR")
    #expect(error.message == "SDK not ready")
  }

  @Test("cacheConsentSolution rejects when SDK is not initialized")
  func cacheConsentSolutionNotInitialized() async throws {
    let module = CookieInformationRNSDKModule()
    let outcome = try await awaitPromise { resolve, reject in
      module.cacheConsentSolution(resolve, rejecter: reject)
    }
    guard case let .rejected(error) = outcome else {
      Issue.record("Expected rejection")
      return
    }
    #expect(error.code == "INIT_ERROR")
    #expect(error.message == "SDK not ready")
  }

  @Test("saveConsents rejects CACHE_ERROR when solution is not cached")
  func saveConsentsWithoutCache() async throws {
    let module = CookieInformationRNSDKModule()
    guard try await BridgeTestSupport.initializeModule(module) else {
      Issue.record("Expected initialize to succeed")
      return
    }

    let outcome = try await awaitPromise { resolve, reject in
      module.saveConsents(
        [["universalId": "a10853b5-85b8-4541-a9ab-fd203176bdce", "accepted": true]] as NSArray,
        customData: nil,
        userId: nil,
        resolver: resolve,
        rejecter: reject
      )
    }
    guard case let .rejected(error) = outcome else {
      Issue.record("Expected rejection")
      return
    }
    #expect(error.code == "CACHE_ERROR")
    #expect(error.message == "Call cacheConsentSolution first")
  }

  @Test("initialize resolves with valid credentials")
  func initializeValidCredentials() async throws {
    let module = CookieInformationRNSDKModule()
    let outcome = try await awaitPromise { resolve, reject in
      module.initialize(BridgeTestSupport.validInitOptions, resolver: resolve, rejecter: reject)
    }
    guard case .resolved(let value) = outcome else {
      Issue.record("Expected resolve")
      return
    }
    #expect(value == nil)
  }

  @Test("removeStoredConsents resolves after initialize")
  func removeStoredConsentsAfterInitialize() async throws {
    let module = CookieInformationRNSDKModule()
    guard try await BridgeTestSupport.initializeModule(module) else {
      Issue.record("Expected initialize to succeed")
      return
    }

    let outcome = try await awaitPromise { resolve, reject in
      module.removeStoredConsents(nil, resolver: resolve, rejecter: reject)
    }
    guard case .resolved(let value) = outcome else {
      Issue.record("Expected resolve")
      return
    }
    #expect(value == nil)
  }

  @Test("getSavedConsents resolves empty array after initialize")
  func getSavedConsentsEmptyAfterInitialize() async throws {
    let module = CookieInformationRNSDKModule()
    guard try await BridgeTestSupport.initializeModule(module) else {
      Issue.record("Expected initialize to succeed")
      return
    }

    let outcome = try await awaitPromise { resolve, reject in
      module.getSavedConsents(nil, resolver: resolve, rejecter: reject)
    }
    guard case .resolved(let value) = outcome else {
      Issue.record("Expected resolve")
      return
    }
    let items = value as? [[String: Any]] ?? []
    #expect(items.isEmpty)
  }

  @Test("synchronizeIfNeeded resolves as no-op on fresh SDK")
  func synchronizeIfNeededFreshSDK() async throws {
    let module = CookieInformationRNSDKModule()
    guard try await BridgeTestSupport.initializeModule(module) else {
      Issue.record("Expected initialize to succeed")
      return
    }

    let outcome = try await awaitPromise { resolve, reject in
      module.synchronizeIfNeeded(resolve, rejecter: reject)
    }
    guard case .resolved(let value) = outcome else {
      Issue.record("Expected resolve")
      return
    }
    #expect(value == nil)
  }


}
