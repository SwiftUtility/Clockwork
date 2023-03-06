import Foundation
import Stencil
import Facility
import FacilityPure
struct GitLoader: Loader {
  var git: Git?
  var templates: Git.Dir
  let parser: StencilParser
  func loadTemplate(name: String, environment: Environment) throws -> Template {
    let content: String
    if let template = parser.cache[name] {
      content = template
    } else if let git = git, let template = try? Execute.parseText(
      reply: parser.execute(git.cat(file: .init(
        ref: templates.ref,
        path: .make(value: "\(templates.path.value)/\(name)")
      )))
    ) {
      content = template
      parser.cache[name] = template
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
