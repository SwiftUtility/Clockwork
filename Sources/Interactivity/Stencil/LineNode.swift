import Foundation
import Facility
import Stencil
final class LineNode: NodeType {
  let nodes: [NodeType]
  let token: Token?
  init(nodes: [NodeType], token: Token) {
    self.nodes = nodes
    self.token = token
  }
  static func parse(parser: TokenParser, token: Token) throws -> NodeType {
    let nodes = try parser.parse(until(["endline"]))
    guard parser.nextToken() != nil else { throw TemplateSyntaxError("`endline` was not found.") }
    return Self(nodes: nodes, token: token)
  }
  func render(_ context: Context) throws -> String {
    return try renderNodes(nodes, context)
      .components(separatedBy: .newlines)
      .joined()
  }
}
