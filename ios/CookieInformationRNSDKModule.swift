import React
import Foundation
import MobileConsentsSDK

@objc(CookieInformationRNSDK)
class CookieInformationRNSDKModule: NSObject {
  private var cookieInformationSDK: MobileConsents?
  private var consentSolutionId: String?
  private var sdkConfig: SDKConfig?
  private var cachedConsentSolution: ConsentSolution?

  private struct SDKConfig {
    let clientID: String
    let clientSecret: String
    let solutionID: String
    let languageCode: String?
    let logNetwork: Bool
    let accentColor: UIColor?
    let fontSet: FontSet?
  }

  @objc static func requiresMainQueueSetup() -> Bool { return true }


  private func withSDK(reject: @escaping RCTPromiseRejectBlock, action: @escaping (MobileConsents) -> Void) {
    guard let sdk = cookieInformationSDK else {
      reject("INIT_ERROR", "SDK not ready", nil)
      return
    }
    action(sdk)
  }

  private func configureSDK() {
    guard let config = sdkConfig else { return }

    cachedConsentSolution = nil
    consentSolutionId = config.solutionID
    let fontSet = config.fontSet ?? .standard
    cookieInformationSDK = MobileConsents(
      uiLanguageCode: config.languageCode,
      clientID: config.clientID,
      clientSecret: config.clientSecret,
      solutionId: config.solutionID,
      accentColor: config.accentColor,
      fontSet: fontSet,
      enableNetworkLogger: config.logNetwork
    )

    NSLog("CookieInformationRNSDK: SDK initialized")
  }

  private func postAcceptAllConsents(
    sdk: MobileConsents,
    solution: ConsentSolution,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    let approvals = ConsentMapping.buildApprovalList(from: solution)
    let payload = Consent(
      consentSolutionId: solution.id,
      consentSolutionVersionId: solution.versionId,
      userConsents: approvals
    )

    sdk.postConsent(payload) { [weak self] error in
      if let error = error {
        reject("SAVE_ERROR", error.localizedDescription, error)
        return
      }
      let consents = ConsentMapping.mapSavedConsents(approvals)
      resolve([
        "success": true,
        "message": "All consents accepted successfully",
        "consents": consents,
        "count": approvals.count
      ] as [String: Any])
    }
  }

  // MARK: - Exported methods

  @objc func initialize(_ options: NSDictionary, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    guard let clientID = options["clientId"] as? String,
          let clientSecret = options["clientSecret"] as? String,
          let solutionID = options["solutionId"] as? String else {
      reject("INVALID_INIT", "clientId, clientSecret, and solutionId are required", nil)
      return
    }
    let languageCode = options["languageCode"] as? String
    let logNetwork = (options["enableNetworkLogger"] as? NSNumber)?.boolValue ?? false
    let ui = options["ui"] as? [String: Any]
    let iosUi = ui?["ios"] as? [String: Any]
    let accentColor = UiParsing.parseHexColor(iosUi?["accentColor"] as? String)
    let fontSet = UiParsing.parseFontSet(iosUi?["fontSet"] as? [String: Any])
    sdkConfig = SDKConfig(
      clientID: clientID,
      clientSecret: clientSecret,
      solutionID: solutionID,
      languageCode: languageCode,
      logNetwork: logNetwork,
      accentColor: accentColor,
      fontSet: fontSet
    )
    configureSDK()
    resolve(nil)
  }

  @objc func showPrivacyPopUp(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    withSDK(reject: reject) { sdk in
      DispatchQueue.main.async { [weak self] in
        sdk.showPrivacyPopUp { selections in
          resolve(ConsentMapping.mapSelections(selections))
        } errorHandler: { error in
          reject("UI_ERROR", error.localizedDescription, error)
        }
      }
    }
  }

  @objc func showPrivacyPopUpIfNeeded(_ options: NSDictionary?, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    let ignoreVersionChanges = (options?["ignoreVersionChanges"] as? NSNumber)?.boolValue ?? false
    withSDK(reject: reject) { sdk in
      DispatchQueue.main.async { [weak self] in
        sdk.showPrivacyPopUpIfNeeded(ignoreVersionChanges: ignoreVersionChanges) { selections in
          resolve(ConsentMapping.mapSelections(selections))
        } errorHandler: { error in
          reject("UI_ERROR", error.localizedDescription, error)
        }
      }
    }
  }

  @objc func acceptAllConsents(_ userId: NSString?, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    withSDK(reject: reject) { [weak self] sdk in
      guard let self = self else {
        reject("MODULE_ERROR", "SDK module unavailable", nil)
        return
      }
      if let solution = self.cachedConsentSolution {
        self.postAcceptAllConsents(sdk: sdk, solution: solution, resolve: resolve, reject: reject)
        return
      }
      sdk.fetchConsentSolution { result in
        switch result {
        case .success(let solution):
          self.cachedConsentSolution = solution
          self.postAcceptAllConsents(sdk: sdk, solution: solution, resolve: resolve, reject: reject)
        case .failure:
          reject("FETCH_ERROR", "Unable to load consent configuration", nil)
        }
      }
    }
  }

  @objc func removeStoredConsents(_ userId: NSString?, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    withSDK(reject: reject) { sdk in
      sdk.removeStoredConsents()
      resolve(nil)
    }
  }

  @objc func cacheConsentSolution(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    withSDK(reject: reject) { [weak self] sdk in
      guard let self = self else {
        reject("MODULE_ERROR", "SDK module unavailable", nil)
        return
      }
      sdk.fetchConsentSolution { result in
        switch result {
        case .success(let solution):
          self.cachedConsentSolution = solution
          let userConsents = solution.consentItems.map { UserConsent(consentItem: $0, isSelected: false) }
          let items = ConsentMapping.mapSavedConsents(userConsents)
          resolve(items)
        case .failure(let error):
          reject("FETCH_ERROR", error.localizedDescription, error)
        }
      }
    }
  }

  @objc func synchronizeIfNeeded(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    withSDK(reject: reject) { sdk in
      sdk.synchronizeIfNeeded()
      resolve(nil)
    }
  }

  @objc func getSavedConsents(_ userId: NSString?, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    withSDK(reject: reject) { [weak self] sdk in
      guard let self = self else {
        reject("MODULE_ERROR", "SDK module unavailable", nil)
        return
      }
      let consents = sdk.getSavedConsents()
      let items = ConsentMapping.mapSavedConsents(consents)
      resolve(items)
    }
  }

  @objc func saveConsents(_ consentItems: NSArray, customData: NSDictionary?, userId: NSString?, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    guard let consentItemsRaw = consentItems as? [[String: Any]] else {
      reject("INVALID_ARGS", "consentItems must be an array of objects", nil)
      return
    }
    let customDataRaw = customData as? [String: String]

    withSDK(reject: reject) { [weak self] sdk in
      guard let self = self else {
        reject("MODULE_ERROR", "SDK module unavailable", nil)
        return
      }

      guard let solution = self.cachedConsentSolution else {
        reject("CACHE_ERROR", "Call cacheConsentSolution first", nil)
        return
      }

      let userConsents = ConsentMapping.buildUserConsents(from: consentItemsRaw, solution: solution)
      guard !userConsents.isEmpty else {
        reject("INVALID_ARGS", "At least one valid consent item with universalId is required", nil)
        return
      }
      let consent = Consent(
        consentSolutionId: solution.id,
        consentSolutionVersionId: solution.versionId,
        customData: customDataRaw,
        userConsents: userConsents
      )
      sdk.postConsent(consent) { error in
        if let error = error {
          reject("SAVE_CONSENTS_ERROR", error.localizedDescription, error)
          return
        }
        let consents = ConsentMapping.mapSavedConsents(userConsents)
        resolve([
          "success": true,
          "savedCount": userConsents.count,
          "consents": consents
        ] as [String: Any])
      }
    }
  }
}
