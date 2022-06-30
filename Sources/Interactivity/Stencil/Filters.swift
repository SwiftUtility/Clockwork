import Foundation
import Facility
import Stencil
enum Filters {
  static func regexp(value: Any?, arguments: [Any?]) throws -> Any? {
    var value = try (value as? String)
      .get { throw TemplateSyntaxError("'regexp' filter expects string value") }
    guard let arguments = (arguments as? [String]), arguments.count == 2 else {
      throw TemplateSyntaxError("'regexp' filter expects 2 string arguments regexp and template")
    }
    let regexp = try NSRegularExpression(
      pattern: arguments[0],
      options: [.anchorsMatchLines]
    )
    let template = arguments[1]
    let matches = regexp.matches(
      in: value,
      options: .withoutAnchoringBounds,
      range: .init(value.startIndex..<value.endIndex, in: value)
    )
    for match in matches.reversed() {
      guard
        match.range.location != NSNotFound,
        let range = Range(match.range, in: value)
      else { continue }
      let matches = (0..<match.numberOfRanges)
        .map(match.range(at:))
        .map { try? String(value[?!.init($0, in: value)]) }
      let replace = try Template(templateString: template).render(["_": matches as Any])
      value.replaceSubrange(range, with: replace)
    }
    return value
  }
  static func incremented(value: Any?) throws -> Any? {
    try 1 + value
      .map { "\($0)" }
      .flatMap(Int.init(_:))
      .get { throw TemplateSyntaxError("'incremented' filter expects Int value") }
  }
  static func emptyLines(value: Any?) throws -> Any? {
    let value = try (value as? String)
      .get { throw TemplateSyntaxError("'emptyLines' filter expects string value") }
    return value
      .components(separatedBy: .newlines)
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
  }
  static func escapeSlack(value: Any?) throws -> Any? {
    let value = try (value as? String)
      .get { throw TemplateSyntaxError("'escapeSlack' filter expects string value") }
    return value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }
  static func escapeUrl(value: Any?) throws -> Any? {
    let value = try (value as? String)
      .get { throw TemplateSyntaxError("'escapeUrl' filter expects string value") }
    return value
      .addingPercentEncoding(withAllowedCharacters: .alphanumerics)
  }
}
