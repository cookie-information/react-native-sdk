import MobileConsentsSDK
import Testing
import UIKit
@testable import CookieInformationRNSDK

@Suite("UiParsing")
struct UiParsingTests {
  @Suite("parseLocalizationOverride")
  struct ParseLocalizationOverrideTests {
    @Test("returns an empty dictionary for nil")
    func nilInput() throws {
      #expect(try UiParsing.parseLocalizationOverride(nil).isEmpty)
      #expect(try UiParsing.parseLocalizationOverride(NSNull()).isEmpty)
    }

    @Test("maps locale keys and all supported labels")
    func supportedLabels() throws {
      let overrides = try UiParsing.parseLocalizationOverride([
        "da": [
          "title": "Privatliv",
          "acceptAllButtonTitle": "Accepter alle",
          "saveSelectionButtonTitle": "Accepter valgte",
          "privacyDescription": "Fortrolighedspolitik",
          "privacyPolicyLongtext": "Lang beskrivelse",
          "readMoreButton": "Fortrolighedspolitik",
          "requiredSectionHeader": "Påkrævet",
          "optionalSectionHeader": "Valgfrit",
          "readMoreScreenHeader": "Privatlivspolitik",
        ],
      ])

      let labels = overrides[Locale(identifier: "da")]
      #expect(labels?.title == "Privatliv")
      #expect(labels?.acceptAllButtonTitle == "Accepter alle")
      #expect(labels?.saveSelectionButtonTitle == "Accepter valgte")
      #expect(labels?.privacyDescription == "Fortrolighedspolitik")
      #expect(labels?.privacyPolicyLongtext == "Lang beskrivelse")
      #expect(labels?.readMoreButton == "Fortrolighedspolitik")
      #expect(labels?.requiredSectionHeader == "Påkrævet")
      #expect(labels?.optionalSectionHeader == "Valgfrit")
      #expect(labels?.readMoreScreenHeader == "Privatlivspolitik")
      #expect(overrides[Locale(identifier: "DA")]?.readMoreButton == "Fortrolighedspolitik")
    }

    @Test("rejects a non-object override")
    func invalidOverride() {
      let error = #expect(throws: UiParsingError.self) {
        try UiParsing.parseLocalizationOverride("Læs mere")
      }
      #expect(error == .invalidLocalizationOverride)
    }

    @Test("rejects an empty locale identifier")
    func emptyLocale() {
      let error = #expect(throws: UiParsingError.self) {
        try UiParsing.parseLocalizationOverride(["  ": [:]])
      }
      #expect(error == .invalidLocale("  "))
    }

    @Test("rejects entries that are not label objects")
    func invalidEntry() {
      let error = #expect(throws: UiParsingError.self) {
        try UiParsing.parseLocalizationOverride(["da": "Læs mere"])
      }
      #expect(error == .invalidLabels("da"))
    }

    @Test("rejects label values that are not strings or null")
    func invalidLabelValue() {
      let error = #expect(throws: UiParsingError.self) {
        try UiParsing.parseLocalizationOverride([
          "da": ["readMoreButton": 123],
        ])
      }
      #expect(error == .invalidLabel(locale: "da", field: "readMoreButton"))
    }
  }

  @Suite("parseHexColor")
  struct ParseHexColorTests {
    @Test("returns nil for nil")
    func nilInput() {
      #expect(UiParsing.parseHexColor(nil) == nil)
    }

    @Test("returns nil without a # prefix")
    func missingHashPrefix() {
      #expect(UiParsing.parseHexColor("FF0000") == nil)
    }

    @Test("returns nil for invalid hex")
    func invalidHex() {
      #expect(UiParsing.parseHexColor("#GGGGGG") == nil)
    }

    @Test("returns nil for unsupported lengths")
    func unsupportedLengths() {
      #expect(UiParsing.parseHexColor("#FFF") == nil)
      #expect(UiParsing.parseHexColor("#FFFFFFFFFF") == nil)
    }

    @Test("parses #RRGGBB")
    func sixDigitHex() {
      let color = UiParsing.parseHexColor("#FF8040")
      #expect(color != nil)
      expectColorComponents(color, red: 1.0, green: 128.0 / 255.0, blue: 64.0 / 255.0, alpha: 1.0)
    }

    @Test("trims surrounding whitespace")
    func trimsWhitespace() {
      let color = UiParsing.parseHexColor("  #00FF00  ")
      #expect(color != nil)
      expectColorComponents(color, red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
    }

    @Test("parses #AARRGGBB")
    func eightDigitHex() {
      let color = UiParsing.parseHexColor("#800000FF")
      #expect(color != nil)
      expectColorComponents(color, red: 0.0, green: 0.0, blue: 1.0, alpha: 128.0 / 255.0)
    }
  }

  @Suite("parseFontSet")
  struct ParseFontSetTests {
    @Test("returns nil for nil")
    func nilInput() {
      #expect(UiParsing.parseFontSet(nil) == nil)
    }

    @Test("applies default sizes and weights for empty input")
    func emptyInputDefaults() {
      let fontSet = UiParsing.parseFontSet([:])
      #expect(fontSet != nil)
      #expect(fontSet?.largeTitle.pointSize == 34)
      #expect(fontWeight(fontSet?.largeTitle) == .bold)
      #expect(fontSet?.body.pointSize == 14)
      #expect(fontWeight(fontSet?.body) == .regular)
      #expect(fontSet?.bold.pointSize == 14)
      #expect(fontWeight(fontSet?.bold) == .bold)
    }

    @Test("parses size and weight for each slot")
    func customFontSpecs() {
      let fontSet = UiParsing.parseFontSet([
        "largeTitle": ["size": 40, "weight": "semibold"],
        "body": ["size": 16, "weight": "medium"],
        "bold": ["size": 18, "weight": "bold"],
      ])
      #expect(fontSet != nil)
      #expect(fontSet?.largeTitle.pointSize == 40)
      #expect(fontWeight(fontSet?.largeTitle) == .semibold)
      #expect(fontSet?.body.pointSize == 16)
      #expect(fontWeight(fontSet?.body) == .medium)
      #expect(fontSet?.bold.pointSize == 18)
      #expect(fontWeight(fontSet?.bold) == .bold)
    }

    @Test("ignores unknown weights and uses slot defaults")
    func unknownWeightUsesDefault() {
      let fontSet = UiParsing.parseFontSet(["body": ["weight": "extrabold"]])
      #expect(fontSet != nil)
      #expect(fontWeight(fontSet?.body) == .regular)
    }

    @Test("accepts weight case-insensitively")
    func caseInsensitiveWeight() {
      let fontSet = UiParsing.parseFontSet(["bold": ["weight": "BOLD"]])
      #expect(fontSet != nil)
      #expect(fontWeight(fontSet?.bold) == .bold)
    }
  }
}

private func expectColorComponents(
  _ color: UIColor?,
  red: CGFloat,
  green: CGFloat,
  blue: CGFloat,
  alpha: CGFloat,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  guard let color = color else {
    Issue.record("Expected a color", sourceLocation: sourceLocation)
    return
  }
  var actualRed: CGFloat = 0
  var actualGreen: CGFloat = 0
  var actualBlue: CGFloat = 0
  var actualAlpha: CGFloat = 0
  color.getRed(&actualRed, green: &actualGreen, blue: &actualBlue, alpha: &actualAlpha)
  let tolerance = 0.001
  #expect(abs(actualRed - red) < tolerance, sourceLocation: sourceLocation)
  #expect(abs(actualGreen - green) < tolerance, sourceLocation: sourceLocation)
  #expect(abs(actualBlue - blue) < tolerance, sourceLocation: sourceLocation)
  #expect(abs(actualAlpha - alpha) < tolerance, sourceLocation: sourceLocation)
}

private func fontWeight(_ font: UIFont?) -> UIFont.Weight {
  guard let font = font else { return .regular }
  let traits = font.fontDescriptor.fontAttributes[.traits] as? [UIFontDescriptor.TraitKey: Any]
  if let rawValue = traits?[.weight] as? CGFloat, rawValue != 0 {
    return UIFont.Weight(rawValue: rawValue)
  }
  for candidate: UIFont.Weight in [.regular, .medium, .semibold, .bold] {
    let expected = UIFont.systemFont(ofSize: font.pointSize, weight: candidate)
    if font.fontDescriptor == expected.fontDescriptor {
      return candidate
    }
  }
  return .regular
}
