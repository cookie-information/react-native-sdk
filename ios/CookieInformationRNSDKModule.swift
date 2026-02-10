import ExpoModulesCore
import Foundation
import MobileConsentsSDK

public class CookieInformationRNSDKModule: Module {
  private var cookieInformationSDK: MobileConsents?
  private var consentSolutionId: String?
  private var consentSolutionVersionId: String?
  private var sdkConfig: SDKConfig?

  private struct SDKConfig {
    let clientID: String
    let clientSecret: String
    let solutionID: String
    let languageCode: String?
    let logNetwork: Bool
    let accentColor: UIColor?
    let fontSet: FontSet?
  }

  private func withSDK(promise: Promise, action: @escaping (MobileConsents) -> Void) {
    guard let sdk = cookieInformationSDK else {
      promise.reject("INIT_ERROR", "SDK not ready")
      return
    }
    action(sdk)
  }


  private func configureSDK() {
    guard let config = sdkConfig else { return }

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

  private func buildApprovalList(from solution: ConsentSolution) -> [UserConsent] {
    solution.consentItems
      .filter { $0.type != .privacyPolicy }
      .map { UserConsent(consentItem: $0, isSelected: true) }
  }

  private func mapSelections(_ approvals: [UserConsent]) -> [String: Bool] {
    approvals.reduce(into: [:]) { dict, consent in
      dict[consent.consentItem.type.rawValue] = consent.isSelected
    }
  }

  private func mapSavedConsents(_ consents: [UserConsent]) -> [[String: Any]] {
    consents.map { consent in
      let item = consent.consentItem
      return [
        "id": 0,
        "universalId": item.id,
        "title": item.translations.primaryTranslation().shortText,
        "description": item.translations.primaryTranslation().longText,
        "required": item.required,
        "type": item.type.rawValue,
        "accepted": consent.isSelected,
      ] as [String: Any]
    }
  }

  public func definition() -> ModuleDefinition {
    Name("CookieInformationRNSDK")

    AsyncFunction("initialize") { (options: [String: Any], promise: Promise) in
      guard let clientID = options["clientId"] as? String,
            let clientSecret = options["clientSecret"] as? String,
            let solutionID = options["solutionId"] as? String else {
        promise.reject("INVALID_INIT", "clientId, clientSecret, and solutionId are required")
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
      promise.resolve(())
    }

    AsyncFunction("showPrivacyPopUp") { (promise: Promise) in
      withSDK(promise: promise) { sdk in
        sdk.showPrivacyPopUp { [weak self] selections in
          promise.resolve(self?.mapSelections(selections) ?? [:])
        } errorHandler: { error in
          promise.reject("UI_ERROR", error.localizedDescription)
        }
      }
    }

    AsyncFunction("showPrivacyPopUpIfNeeded") { (options: [String: Any]?, promise: Promise) in
      let ignoreVersionChanges = (options?["ignoreVersionChanges"] as? NSNumber)?.boolValue ?? false
      withSDK(promise: promise) { sdk in
        sdk.showPrivacyPopUpIfNeeded(ignoreVersionChanges: ignoreVersionChanges) { [weak self] selections in
          promise.resolve(self?.mapSelections(selections) ?? [:])
        } errorHandler: { error in
          promise.reject("UI_ERROR", error.localizedDescription)
        }
      }
    }

    AsyncFunction("acceptAllConsents") { (promise: Promise) in
      withSDK(promise: promise) { sdk in
        sdk.fetchConsentSolution { [weak self] result in
          switch result {
          case .success(let solution):
            let approvals = self?.buildApprovalList(from: solution) ?? []
            let payload = Consent(
              consentSolutionId: solution.id,
              consentSolutionVersionId: solution.versionId,
              userConsents: approvals
            )

            sdk.postConsent(payload) { [weak self] error in
              if let error = error {
                promise.reject("SAVE_ERROR", error.localizedDescription)
                return
              }
              promise.resolve(self?.mapSelections(approvals) ?? [:])
            }
          case .failure:
            promise.reject("FETCH_ERROR", "Unable to load consent configuration")
          }
        }
      }
    }

    AsyncFunction("removeStoredConsents") { (_: String?, promise: Promise) in
      withSDK(promise: promise) { sdk in
        sdk.removeStoredConsents()
        promise.resolve(())
      }
    }

    AsyncFunction("cacheConsentSolution") { (promise: Promise) in
      withSDK(promise: promise) { [weak self] sdk in
        guard let self = self else {
          promise.reject("MODULE_ERROR", "SDK module unavailable")
          return
        }
        sdk.fetchConsentSolution { result in
          switch result {
          case .success(let solution):
            self.consentSolutionVersionId = solution.versionId
            let userConsents = solution.consentItems.map { UserConsent(consentItem: $0, isSelected: false) }
            let items = self.mapSavedConsents(userConsents)
            promise.resolve([
              "consentItems": items,
              "consentSolutionVersionId": solution.versionId
            ])
          case .failure(let error):
            promise.reject("FETCH_ERROR", error.localizedDescription)
          }
        }
      }
    }

    AsyncFunction("synchronizeIfNeeded") { (promise: Promise) in
      withSDK(promise: promise) { sdk in
        sdk.synchronizeIfNeeded()
        promise.resolve(())
      }
    }

    AsyncFunction("getSavedConsents") { (_: String?, promise: Promise) in
      withSDK(promise: promise) { [weak self] sdk in
        guard let self = self else {
          promise.reject("MODULE_ERROR", "SDK module unavailable")
          return
        }
        let consents = sdk.getSavedConsents()
        let items = self.mapSavedConsents(consents)
        promise.resolve(["consentItems": items])
      }
    }

    AsyncFunction("saveConsents") { (consentItemsRaw: [[String: Any]], customDataRaw: [String: String]?, _: String?, consentSolutionVersionId: String?, promise: Promise) in
      withSDK(promise: promise) { sdk in
        guard let solutionId = self.consentSolutionId, !solutionId.isEmpty else {
          promise.reject("NO_CONFIG", "CookieInformation.plist missing or solutionID not set")
          return
        }
        let versionId = consentSolutionVersionId ?? self.consentSolutionVersionId
        guard let versionId = versionId else {
          promise.reject("NO_VERSION", "Call cacheConsentSolution first or provide consentSolutionVersionId")
          return
        }
        var consent = Consent(
          consentSolutionId: solutionId,
          consentSolutionVersionId: versionId,
          customData: customDataRaw,
          userConsents: []
        )
        let language = "EN"
        for itemDict in consentItemsRaw {
          guard let universalId = itemDict["universalId"] as? String,
                let accepted = itemDict["accepted"] as? Bool else { continue }
          let purpose = ProcessingPurpose(consentItemId: universalId, consentGiven: accepted, language: language)
          consent.addProcessingPurpose(purpose)
        }
        sdk.postConsent(consent) { error in
          if let error = error {
            promise.reject("SAVE_CONSENTS_ERROR", error.localizedDescription)
            return
          }
        let count = consent.processingPurposes.count
        promise.resolve(["success": true, "savedCount": count] as [String: Any])
        }
      }
    }
  }
}
