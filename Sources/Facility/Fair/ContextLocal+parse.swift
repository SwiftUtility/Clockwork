import Foundation
import Facility
import FacilityPure
public extension ContextLocal {
  func log(message: String) {
    sh.stderr(.init("[\(sh.formatter.string(from: sh.getTime()))]: \(message)\n".utf8))
  }
  func parse(secret: Ctx.Secret) throws -> String {
    switch secret {
    case .value(let value): return value
    case .envVar(let envVar): return try sh.get(env: envVar)
    case .envFile(let envFile): return try Id.make(envFile)
      .map(sh.get(env:))
      .map(Ctx.Sys.Absolute.make(value:))
      .map(sh.read)
      .map(String.make(utf8:))
      .get()
    case .sysFile(let sysFile): return try Id(sysFile)
      .map(Ctx.Sys.Absolute.Resolve.make(path:))
      .map(sh.resolveAbsolute)
      .map(sh.read)
      .map(String.make(utf8:))
      .get()
    case .gitFile(let gitFile): return try Id(gitFile)
      .reduce(sh, repo.git.cat(sh:file:))
      .map(String.make(utf8:))
      .get()
    }
  }
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
}
private extension ContextLocal {
  func parse<T: Decodable>(type: T.Type, yaml: Ctx.Git.File) throws -> T {
    let yaml = try Id
    .make(yaml)
    .reduce(sh, repo.git.cat(sh:file:))
    .map(String.make(utf8:))
    .map(sh.unyaml)
    .get()
    return try sh.dialect.read(type, from: yaml)
  }
}
