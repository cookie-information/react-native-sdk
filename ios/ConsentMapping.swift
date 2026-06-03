import Foundation
import MobileConsentsSDK

enum ConsentMapping {
  static func buildApprovalList(from solution: ConsentSolution) -> [UserConsent] {
    solution.consentItems
      .filter { $0.type != .privacyPolicy }
      .map { UserConsent(consentItem: $0, isSelected: true) }
  }

  static func buildUserConsents(
    from consentItemsRaw: [[String: Any]],
    solution: ConsentSolution
  ) -> [UserConsent] {
    var userConsents: [UserConsent] = []
    for itemDict in consentItemsRaw {
      guard let universalId = itemDict["universalId"] as? String,
            let accepted = itemDict["accepted"] as? Bool else { continue }
      guard let consentItem = solution.consentItems.first(where: { $0.id == universalId }),
            consentItem.type != .privacyPolicy else { continue }
      userConsents.append(UserConsent(consentItem: consentItem, isSelected: accepted))
    }
    return userConsents
  }

  static func mapSelections(_ approvals: [UserConsent]) -> [String: Bool] {
    approvals.reduce(into: [:]) { dict, consent in
      dict[consent.consentItem.type.rawValue] = consent.isSelected
    }
  }

  static func mapSavedConsents(_ consents: [UserConsent]) -> [[String: Any]] {
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
}
