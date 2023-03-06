import Foundation
import Stencil
import Facility
import FacilityPure
public final class StencilParser {
  let notation: AnyCodable.Notation
  let extensions: [Extension]
  let execute: Try.Reply<Execute>
  var cache: [String: String]
  public init(
    execute: @escaping Try.Reply<Execute>,
    notation: AnyCodable.Notation,
    cache: [String: String] = [:]
  ) {
    self.notation = notation
    self.execute = execute
    let extensions = Extension()
    extensions.registerFilter("incremented", filter: Filters.incremented(value:))
    extensions.registerFilter("emptyLines", filter: Filters.emptyLines(value:))
    extensions.registerFilter("escapeSlack", filter: Filters.escapeSlack(value:))
    extensions.registerFilter("escapeJson", filter: Filters.escapeJson(value:))
    extensions.registerFilter("escapeUrlQueryAllowed", filter: Filters.escapeUrlQueryAllowed(value:))
    extensions.registerFilter("stride", filter: Filters.stride(value:args:))
    extensions.registerTag("scan", parser: ScanNode.parse(parser:token:))
    extensions.registerTag("line", parser: LineNode.parse(parser:token:))
    self.extensions = [extensions]
    self.cache = cache
  }
  public func generate(query: Generate) throws -> Generate.Reply {
    guard let context = try notation.write(query.info).anyObject as? [String: Any]
    else { throw MayDay("Wrong info format") }
    var result: String
    let environment = Environment(
      loader: query.git.map({ GitLoader(git: $0, templates: query.templates, parser: self) }),
      extensions: extensions
    )
    switch query.template {
    case .name(let value): result = try environment.renderTemplate(name: value, context: context)
    case .value(let value): result = try environment.renderTemplate(string: value, context: context)
    }
    result = result.trimmingCharacters(in: .newlines)
    guard query.allowEmpty || !result.isEmpty
    else { throw Thrown("Empty rendering \(query.template.name)") }
    return result
  }
}
