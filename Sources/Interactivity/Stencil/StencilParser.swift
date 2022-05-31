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
    let result = try query.environment
      .loadTemplate(name: query.template)
      .render(context as? [String: Any])
      .trimmingCharacters(in: .newlines)
    return result.isEmpty.else(result)
  }
}
extension RenderStencil {
  var environment: Environment {
    let ext = Extension()
    ext.registerFilter("regexp", filter: Self.regexp(value:arguments:))
    return .init(loader: DictionaryLoader(templates: templates), extensions: [ext])
  }
  static func regexp(value: Any?, arguments: [Any?]) throws -> Any? {
    do {
      var value = try ?!(value as? String)
      var arguments = try ?!(arguments as? [String])
      guard !arguments.isEmpty else { throw Thrown() }
      let regexp = try NSRegularExpression(
        pattern: arguments.removeFirst(),
        options: [.anchorsMatchLines]
      )
      let template = arguments.isEmpty.else(arguments.removeFirst()).or("")
      let matches = regexp.matches(
        in: value,
        options: .withoutAnchoringBounds,
        range: .init(value.startIndex..<value.endIndex, in: value)
      )
      for match in matches.reversed() {
        guard match.range.location != NSNotFound else { continue }
        let matches = try? (0..<match.numberOfRanges)
          .map(match.range(at:))
          .map { try value[?!.init($0, in: value)] }
          .map(String.init(_:))
        let replace = try? Template(templateString: template).render(["_": matches as Any])
        try? value.replaceSubrange(?!.init(match.range, in: value), with: ?!replace)
      }
      return value
    } catch { return value }
  }
}
