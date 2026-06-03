import Foundation
import MobileConsentsSDK
import Testing
@testable import CookieInformationRNSDK

private enum ConsentFixtures {
  static func solution() throws -> ConsentSolution {
    let data = Data(minimalSolutionJSON.utf8)
    return try JSONDecoder().decode(ConsentSolution.self, from: data)
  }

  static func consentItem(in solution: ConsentSolution, id: String) -> ConsentItem? {
    solution.consentItems.first { $0.id == id }
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
      },
      {
        "universalConsentItemId": "7d477dbf-5f88-420f-8dfc-2506907ebe07",
        "required": true,
        "type": "privacy policy",
        "translations": [
          {"language": "EN", "shortText": "Privacy policy", "longText": "Privacy policy text"}
        ]
      }
    ]
  }
  """
}

@Suite("ConsentMapping")
struct ConsentMappingTests {
  private let necessaryId = "a10853b5-85b8-4541-a9ab-fd203176bdce"
  private let marketingId = "ef7d8f35-fc1a-4369-ada2-c00cc0eecc4b4"
  private let privacyPolicyId = "7d477dbf-5f88-420f-8dfc-2506907ebe07"

  @Test("buildUserConsents maps universalId and accepted to UserConsent")
  func buildUserConsentsMapsValidItems() throws {
    let solution = try ConsentFixtures.solution()
    let raw: [[String: Any]] = [
      ["universalId": necessaryId, "accepted": true],
      ["universalId": marketingId, "accepted": false],
    ]

    let result = ConsentMapping.buildUserConsents(from: raw, solution: solution)

    #expect(result.count == 2)
    #expect(result[0].consentItem.id == necessaryId)
    #expect(result[0].isSelected == true)
    #expect(result[1].consentItem.id == marketingId)
    #expect(result[1].isSelected == false)
  }

  @Test("buildUserConsents skips privacy policy and unknown items")
  func buildUserConsentsSkipsInvalidItems() throws {
    let solution = try ConsentFixtures.solution()
    let raw: [[String: Any]] = [
      ["universalId": privacyPolicyId, "accepted": true],
      ["universalId": "unknown-id", "accepted": true],
      ["universalId": necessaryId, "accepted": true],
      ["universalId": marketingId],
      ["accepted": false],
    ]

    let result = ConsentMapping.buildUserConsents(from: raw, solution: solution)

    #expect(result.count == 1)
    #expect(result[0].consentItem.id == necessaryId)
  }

  @Test("mapSavedConsents maps UserConsent to JS consent item shape")
  func mapSavedConsentsShape() throws {
    let solution = try ConsentFixtures.solution()
    guard let item = ConsentFixtures.consentItem(in: solution, id: marketingId) else {
      Issue.record("Expected marketing consent item in fixture")
      return
    }
    let consents = [UserConsent(consentItem: item, isSelected: true)]

    let result = ConsentMapping.mapSavedConsents(consents)

    #expect(result.count == 1)
    let mapped = result[0]
    #expect(mapped["id"] as? Int == 0)
    #expect(mapped["universalId"] as? String == marketingId)
    #expect(mapped["title"] as? String == "Marketing cookies")
    #expect(mapped["description"] as? String == "Marketing long text")
    #expect(mapped["required"] as? Bool == false)
    #expect(mapped["type"] as? String == ConsentItemType.marketing.rawValue)
    #expect(mapped["accepted"] as? Bool == true)
  }

  @Test("mapSelections maps consent types to selection dictionary")
  func mapSelectionsByType() throws {
    let solution = try ConsentFixtures.solution()
    guard let necessary = ConsentFixtures.consentItem(in: solution, id: necessaryId),
          let marketing = ConsentFixtures.consentItem(in: solution, id: marketingId) else {
      Issue.record("Expected consent items in fixture")
      return
    }
    let consents = [
      UserConsent(consentItem: necessary, isSelected: true),
      UserConsent(consentItem: marketing, isSelected: false),
    ]

    let result = ConsentMapping.mapSelections(consents)

    #expect(result[ConsentItemType.necessary.rawValue] == true)
    #expect(result[ConsentItemType.marketing.rawValue] == false)
  }

  @Test("buildApprovalList accepts all non-privacy-policy items")
  func buildApprovalListExcludesPrivacyPolicy() throws {
    let solution = try ConsentFixtures.solution()
    let result = ConsentMapping.buildApprovalList(from: solution)

    #expect(result.count == 2)
    #expect(result.allSatisfy { $0.isSelected })
    #expect(result.contains(where: { $0.consentItem.id == necessaryId }))
    #expect(result.contains(where: { $0.consentItem.id == marketingId }))
    #expect(!result.contains(where: { $0.consentItem.type == .privacyPolicy }))
  }
}
