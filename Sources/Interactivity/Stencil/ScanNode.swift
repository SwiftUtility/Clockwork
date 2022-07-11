import Foundation
import Facility
import Stencil
final class ScanNode: NodeType {
  let regexp: Variable
  let area: [NodeType]
  let patch: [NodeType]
  let token: Token?
  init(regexp: Variable, area: [NodeType], patch: [NodeType], token: Token) {
    self.regexp = regexp
    self.area = area
    self.patch = patch
    self.token = token
  }
  static func parse(parser: TokenParser, token: Token) throws -> NodeType {
    let components = token.components
    guard components.count == 2 else {
      throw TemplateSyntaxError("'scan' tag takes one argument, the regexp expression")
    }
    let area = try parser.parse(until(["patch"]))
    guard parser.nextToken() != nil else { throw TemplateSyntaxError("`patch` was not found.") }
    let patch = try parser.parse(until(["endscan"]))
    guard parser.nextToken() != nil else { throw TemplateSyntaxError("`endscan` was not found.") }
    return Self(regexp: .init(components[1]), area: area, patch: patch, token: token)
  }
  func render(_ context: Context) throws -> String {
    guard let regexp = try? NSRegularExpression(
      pattern: ?!(regexp.resolve(context) as? String),
      options: [.anchorsMatchLines]
    ) else { throw TemplateSyntaxError("regexp not valid") }
    var value = try renderNodes(area, context)
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
      let replace = try context.push(dictionary: ["_": matches] as [String: Any]) {
        try renderNodes(patch, context)
      }
      value.replaceSubrange(range, with: replace)
    }
    return value
  }
}
