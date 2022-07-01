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
    switch query.template {
    case .name(let name): name.debug()
    case .value(let value): value.debug()
    }
    let context = try notation
      .write(query.context)
      .anyObject
    as? [String: Any] ?? [:]
    let ext = Extension()
    ext.registerFilter("regexp", filter: Filters.regexp(value:arguments:))
    ext.registerFilter("incremented", filter: Filters.incremented(value:))
    ext.registerFilter("emptyLines", filter: Filters.emptyLines(value:))
    ext.registerFilter("escapeSlack", filter: Filters.escapeSlack(value:))
    ext.registerFilter("escapeUrl", filter: Filters.escapeUrl(value:))
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
    result.debug()
    guard query.allowEmpty || !result.isEmpty
    else { throw Thrown("Empty rendering result") }
    return result
  }
}
