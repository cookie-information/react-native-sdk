import Foundation
import MobileConsentsSDK
import UIKit

enum UiParsing {
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
