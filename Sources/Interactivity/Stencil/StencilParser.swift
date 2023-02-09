import Foundation
import Stencil
import Facility
import FacilityPure
public struct StencilParser {
  let notation: AnyCodable.Notation
  public init(notation: AnyCodable.Notation) {
    self.notation = notation
  }
  public func generate(query: Generate) throws -> Generate.Reply {
    guard let context = try notation.write(query.info).anyObject as? [String: Any]
    else { throw MayDay("Wrong info format") }
    let ext = Extension()
    ext.registerFilter("incremented", filter: Filters.incremented(value:))
    ext.registerFilter("emptyLines", filter: Filters.emptyLines(value:))
    ext.registerFilter("escapeSlack", filter: Filters.escapeSlack(value:))
    ext.registerFilter("escapeJson", filter: Filters.escapeJson(value:))
    ext.registerFilter("escapeUrlQueryAllowed", filter: Filters.escapeUrlQueryAllowed(value:))
    ext.registerFilter("stride", filter: Filters.stride(value:args:))
    ext.registerTag("scan", parser: ScanNode.parse(parser:token:))
    ext.registerTag("line", parser: LineNode.parse(parser:token:))
    var result: String
    switch query.template {
    case .name(let value): result = try Environment
      .init(
        loader: DictionaryLoader(templates: query.templates),
        extensions: [ext]
      )
      .renderTemplate(name: value, context: context)
    case .value(let value): result = try Environment
      .init(extensions: [ext])
      .renderTemplate(string: value, context: context)
    }
    result = result.trimmingCharacters(in: .newlines)
    guard query.info.allowEmpty || !result.isEmpty
    else { throw Thrown("Empty rendering result") }
    return result
  }
}
