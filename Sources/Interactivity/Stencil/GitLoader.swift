import Foundation
import Stencil
import Facility
import FacilityPure
import FacilityFair
final class GitLoader: Loader {
  let git: Ctx.Git
  let ref: Ctx.Git.Ref
  let prefix: String
  let sh: Ctx.Sh
  var cache: [String: String]
  init?(sh: Ctx.Sh?, git: Ctx.Git?, profile: Profile?) {
    guard let sh = sh, let git = git, let profile = profile, let templates = profile.templates
    else { return nil }
    self.sh = sh
    self.cache = [:]
    self.git = git
    self.ref = profile.location.ref
    self.prefix = "\(templates.path.value)/"
  }
  func loadTemplate(name: String, environment: Environment) throws -> Template {
    let content: String
    if let template = cache[name] {
      content = template
    } else if let template = try? String.make(utf8: sh.cat(
      git: git, file: .make(ref: ref, path: .make(value: "\(prefix)\(name)"))
    )) {
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
