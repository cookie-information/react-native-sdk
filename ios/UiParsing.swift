import Foundation
import MobileConsentsSDK
import UIKit

enum UiParsingError: LocalizedError, Equatable {
  case invalidLocalizationOverride
  case invalidLocale(String)
  case invalidLabels(String)
  case invalidLabel(locale: String, field: String)

  var errorDescription: String? {
    switch self {
    case .invalidLocalizationOverride:
      return "ui.ios.localizationOverride must be an object keyed by locale"
    case .invalidLocale(let locale):
      return "Invalid locale identifier: \(locale)"
    case .invalidLabels(let locale):
      return "Localization override for \(locale) must be an object"
    case .invalidLabel(let locale, let field):
      return "\(field) for locale \(locale) must be a string or null"
    }
  }
}

enum UiParsing {
  static func parseLocalizationOverride(_ rawValue: Any?) throws -> [Locale: LabelText] {
    guard let rawValue = rawValue, !(rawValue is NSNull) else { return [:] }
    guard let value = rawValue as? [String: Any] else {
      throw UiParsingError.invalidLocalizationOverride
    }

    return try value.reduce(into: [Locale: LabelText]()) { result, entry in
      let localeIdentifier = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !localeIdentifier.isEmpty else {
        throw UiParsingError.invalidLocale(entry.key)
      }
      guard let labels = entry.value as? [String: Any] else {
        throw UiParsingError.invalidLabels(localeIdentifier)
      }
      result[Locale(identifier: localeIdentifier)] = LabelText(
        title: try optionalString("title", from: labels, locale: localeIdentifier),
        acceptAllButtonTitle: try optionalString("acceptAllButtonTitle", from: labels, locale: localeIdentifier),
        saveSelectionButtonTitle: try optionalString("saveSelectionButtonTitle", from: labels, locale: localeIdentifier),
        privacyDescription: try optionalString("privacyDescription", from: labels, locale: localeIdentifier),
        privacyPolicyLongtext: try optionalString("privacyPolicyLongtext", from: labels, locale: localeIdentifier),
        readMoreButton: try optionalString("readMoreButton", from: labels, locale: localeIdentifier),
        requiredSectionHeader: try optionalString("requiredSectionHeader", from: labels, locale: localeIdentifier),
        optionalSectionHeader: try optionalString("optionalSectionHeader", from: labels, locale: localeIdentifier),
        readMoreScreenHeader: try optionalString("readMoreScreenHeader", from: labels, locale: localeIdentifier)
      )
    }
  }

  private static func optionalString(
    _ key: String,
    from labels: [String: Any],
    locale: String
  ) throws -> String? {
    guard let value = labels[key], !(value is NSNull) else { return nil }
    guard let string = value as? String else {
      throw UiParsingError.invalidLabel(locale: locale, field: key)
    }
    return string
  }

  static func parseHexColor(_ value: String?) -> UIColor? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          value.hasPrefix("#") else {
      return nil
    }
    let hex = String(value.dropFirst())
    var rgba: UInt64 = 0
    let scanner = Scanner(string: hex)
    guard scanner.scanHexInt64(&rgba) else { return nil }
    if hex.count == 6 {
      let r = CGFloat((rgba & 0xFF0000) >> 16) / 255.0
      let g = CGFloat((rgba & 0x00FF00) >> 8) / 255.0
      let b = CGFloat(rgba & 0x0000FF) / 255.0
      return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    if hex.count == 8 {
      let a = CGFloat((rgba & 0xFF000000) >> 24) / 255.0
      let r = CGFloat((rgba & 0x00FF0000) >> 16) / 255.0
      let g = CGFloat((rgba & 0x0000FF00) >> 8) / 255.0
      let b = CGFloat(rgba & 0x000000FF) / 255.0
      return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    return nil
  }

  static func parseFontSet(_ value: [String: Any]?) -> FontSet? {
    guard let value = value else { return nil }
    let largeTitle = parseFontSpec(value["largeTitle"] as? [String: Any], defaultSize: 34, defaultWeight: .bold)
    let body = parseFontSpec(value["body"] as? [String: Any], defaultSize: 14, defaultWeight: .regular)
    let bold = parseFontSpec(value["bold"] as? [String: Any], defaultSize: 14, defaultWeight: .bold)
    return FontSet(largeTitle: largeTitle, body: body, bold: bold)
  }

  private static func parseFontSpec(_ value: [String: Any]?, defaultSize: CGFloat, defaultWeight: UIFont.Weight) -> UIFont {
    let size = (value?["size"] as? NSNumber)?.doubleValue ?? Double(defaultSize)
    let weight = parseWeight(value?["weight"] as? String) ?? defaultWeight
    if let name = value?["name"] as? String, let font = UIFont(name: name, size: size) {
      return font
    }
    return UIFont.systemFont(ofSize: size, weight: weight)
  }

  private static func parseWeight(_ value: String?) -> UIFont.Weight? {
    guard let value = value?.lowercased() else { return nil }
    switch value {
    case "regular": return .regular
    case "medium": return .medium
    case "semibold": return .semibold
    case "bold": return .bold
    default: return nil
    }
  }
}
