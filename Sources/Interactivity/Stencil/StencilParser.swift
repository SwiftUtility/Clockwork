import Foundation
import Stencil
import Facility
import FacilityPure
public final class StencilParser {
  let notation: AnyCodable.Notation
  let environment: Environment
  public init(
    notation: AnyCodable.Notation,
    sh: Ctx.Sh? = nil,
    git: Ctx.Git? = nil,
    profile: Profile? = nil,
    cache: [String: String] = [:]
  ) {
    self.notation = notation
    let extensions = Extension()
    extensions.registerFilter("incremented", filter: Filters.incremented(value:))
    extensions.registerFilter("emptyLines", filter: Filters.emptyLines(value:))
    extensions.registerFilter("escapeSlack", filter: Filters.escapeSlack(value:))
    extensions.registerFilter("escapeJson", filter: Filters.escapeJson(value:))
    extensions.registerFilter("escapeUrlQueryAllowed", filter: Filters.escapeUrlQueryAllowed(value:))
    extensions.registerFilter("stride", filter: Filters.stride(value:args:))
    extensions.registerTag("scan", parser: ScanNode.parse(parser:token:))
    extensions.registerTag("line", parser: LineNode.parse(parser:token:))
    let loader: Loader
    if let sh = sh, let git = git, let profile = profile {
      loader = GitLoader(sh: sh, git: git, profile: profile)
    } else {
      loader = DictionaryLoader(templates: cache)
    }
    self.environment = Environment(loader: loader, extensions: [extensions])
  }
  public func generate(query: Generate) throws -> Generate.Reply {
    guard let context = try notation.write(query.info).anyObject as? [String: Any]
    else { throw MayDay("Wrong info format") }
    var result: String
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
