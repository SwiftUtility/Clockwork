import Foundation
import Facility
import FacilityPure
extension ContextShell {
  func parseGitlab() throws -> Ctx.Gitlab.Cfg? { try repo.profile.gitlab
    .reduce(Yaml.Gitlab.self, parse(type:yaml:))
    .map(Ctx.Gitlab.Cfg.make(yaml:))
  }
  func parseCodeOwnage(profile: Profile? = nil) throws -> [String: Criteria]? {
    guard let codeOwnage = profile.get(repo.profile).codeOwnage else { return nil }
    return try parse(type: [String: Yaml.Criteria].self, yaml: codeOwnage)
      .mapValues(Criteria.init(yaml:))
  }
  func parseFileTaboos() throws -> [FileTaboo] {
    guard let fileTaboos = repo.profile.fileTaboos
    else { throw Thrown("No fileTaboos in profile") }
    return try parse(type: [Yaml.FileTaboo].self, yaml: fileTaboos)
      .map(FileTaboo.init(yaml:))
  }
  func parseCocoapods() throws -> Cocoapods {
    guard let cocoapods = repo.profile.cocoapods
    else { throw Thrown("No cocoapods in profile") }
    return try Cocoapods.make(
      path: cocoapods.path,
      yaml: parse(type: Yaml.Cocoapods.self, yaml: cocoapods)
    )
  }
  func parseRequisition() throws -> Requisition {
    guard let requisition = repo.profile.requisition
    else { throw Thrown("No requisition in profile") }
    return try Requisition.make(yaml: parse(type: Yaml.Requisition.self, yaml: requisition))
  }
}
private extension ContextShell {
  func parse<T: Decodable>(type: T.Type, yaml: Ctx.Git.File) throws -> T {
    let yaml = try Id
    .make(yaml)
    .map(gitCat(file:))
    .map(String.make(utf8:))
    .map(sh.unyaml)
    .get()
    return try sh.dialect.read(type, from: yaml)
  }
}
