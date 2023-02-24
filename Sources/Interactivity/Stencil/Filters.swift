import Foundation
import Facility
import Stencil
enum Filters {
  static func incremented(value: Any?) throws -> Any? {
    if let value = value as? Int {
      return value + 1
    } else if let value = value as? String {
      if let value = Int(value) { return value + 1 }
    }
    throw TemplateSyntaxError("incremented: not Int: \(value ?? "")")
  }
  static func emptyLines(value: Any?) throws -> Any? {
    let value = try (value as? String)
      .get { throw TemplateSyntaxError("emptyLines: not String \(value ?? "")") }
    return value
      .components(separatedBy: .newlines)
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
  }
  static func escapeSlack(value: Any?) throws -> Any? {
    let value = try (value as? String)
      .get { throw TemplateSyntaxError("escapeSlack not String \(value ?? "")") }
    return value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }
  static func escapeJson(value: Any?) throws -> Any? {
    let value = try (value as? String)
      .get { throw TemplateSyntaxError("escapeJson not String \(value ?? "")") }
      .trimmingCharacters(in: .newlines)
    return try String(data: JSONEncoder().encode(value), encoding: .utf8)
  }
  static func escapeUrlQueryAllowed(value: Any?) throws -> Any? {
    let value = try (value as? String)
      .get { throw TemplateSyntaxError("escapeUrlQueryAllowed: not String \(value ?? "")") }
    return value
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
  }
  static func stride(value: Any?, args: [Any?]) throws -> Any? {
    guard let value = value as? [Any?]
    else { throw TemplateSyntaxError("stride: not Array \(value ?? "nil")") }
    guard let count = args.first as? Int, count >= 0
    else { throw TemplateSyntaxError("stride: no positive int argument") }
    return Swift.stride(from: 0, to: value.count, by: count)
      .map({ Array(value.suffix(from: $0).prefix(count)) })
  }
}
