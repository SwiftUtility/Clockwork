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
    let context = try notation
      .write(query.context)
      .anyObject
    let ext = Extension()
    ext.registerFilter("regexp", filter: Filters.regexp(value:arguments:))
    ext.registerFilter("incremented", filter: Filters.incremented(value:))
    ext.registerTag("scan", parser: ScanNode.parse(parser:token:))
    ext.registerTag("line", parser: LineNode.parse(parser:token:))
    let result = try Environment
      .init(loader: DictionaryLoader(templates: query.templates), extensions: [ext])
      .loadTemplate(name: query.template)
      .render(context as? [String: Any])
      .trimmingCharacters(in: .newlines)
    guard !result.isEmpty else { throw Thrown("Empty result for \(query.template)") }
    return result
  }
}
