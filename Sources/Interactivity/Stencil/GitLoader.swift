import Foundation
import Stencil
import Facility
import FacilityPure
import FacilityFair
final class GitLoader: Loader {
  let ctx: ContextRepo
  let prefix: String
  var cache: [String: String] = [:]
  init?(ctx: ContextRepo?) {
    guard
      let ctx = ctx, let templates = ctx.repo.profile.templates
    else { return nil }
    self.ctx = ctx
    self.prefix = templates.path.value.isEmpty.not.then("\(templates.path.value)/").get("")
  }
  func loadTemplate(name: String, environment: Environment) throws -> Template {
    let content: String
    if let template = cache[name] {
      content = template
    } else if let template = try? String.make(utf8: ctx.gitCat(file: .make(
      ref: ctx.repo.initialSha.ref,
      path: .make(value: "\(prefix)\(name)")
    ))) {
      content = template
      cache[name] = template
    } else {
      throw TemplateDoesNotExist(templateNames: [name], loader: self)
    }
    return environment.templateClass.init(
      templateString: content,
      environment: environment,
      name: name
    )
  }
}
