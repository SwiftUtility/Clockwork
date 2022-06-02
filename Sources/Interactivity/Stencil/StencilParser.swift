import Foundation
import Stencil
import Facility
import FacilityQueries
public struct StencilParser {
  let notation: AnyCodable.Notation
  public init(notation: AnyCodable.Notation) {
    self.notation = notation
  }
  public func renderStencil(query: RenderStencil) throws -> RenderStencil.Reply {
    let context = try notation
      .write(query.context)
      .anyObject
    let ext = Extension()
    ext.registerFilter("regexp", filter: Filters.regexp(value:arguments:))
    ext.registerFilter("incremented", filter: Filters.incremented(value:))
    ext.registerTag("scan", parser: ScanNode.parse(parser:token:))
    let result = try Environment
      .init(loader: DictionaryLoader(templates: query.templates), extensions: [ext])
      .loadTemplate(name: query.template)
      .render(context as? [String: Any])
      .trimmingCharacters(in: .newlines)
    return result.isEmpty.else(result)
  }
}
