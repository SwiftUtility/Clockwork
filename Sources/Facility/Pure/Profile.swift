import Foundation
import Facility
public struct Profile {
  public var location: Ctx.Git.File
  public var version: String
  public var storageBranch: Ctx.Git.Branch?
  public var storageTemplate: Template?
  public var gitlab: Ctx.Git.File?
  public var slack: Ctx.Git.File?
  public var rocket: Ctx.Git.File?
  public var jira: Ctx.Git.File?
  public var templates: Ctx.Git.Dir?
  public var codeOwnage: Ctx.Git.File?
  public var review: Ctx.Git.File?
  public var fileTaboos: Ctx.Git.File?
  public var cocoapods: Ctx.Git.File?
  public var production: Ctx.Git.File?
  public var requisition: Ctx.Git.File?
  public static func make(
    location: Ctx.Git.File,
    yaml: Yaml.Profile
  ) throws -> Self { try .init(
    location: location,
    version: yaml.version,
    storageBranch: yaml.storage.map(\.branch).map(Ctx.Git.Branch.make(name:)),
    storageTemplate: yaml.storage.map(\.createCommitMessage).map(Template.make(yaml:)),
    gitlab: yaml.gitlab
      .map(Ctx.Sys.Relative.init(value:))
      .reduce(location.ref, Ctx.Git.File.make(ref:path:)),
    slack: yaml.slack
      .map(Ctx.Sys.Relative.init(value:))
      .reduce(location.ref, Ctx.Git.File.make(ref:path:)),
    rocket: yaml.rocket
      .map(Ctx.Sys.Relative.init(value:))
      .reduce(location.ref, Ctx.Git.File.make(ref:path:)),
    jira: yaml.jira
      .map(Ctx.Sys.Relative.init(value:))
      .reduce(location.ref, Ctx.Git.File.make(ref:path:)),
    templates: yaml.templates
      .map(Ctx.Sys.Relative.init(value:))
      .reduce(location.ref, Ctx.Git.Dir.make(ref:path:)),
    codeOwnage: yaml.codeOwnage
      .map(Ctx.Sys.Relative.init(value:))
      .reduce(location.ref, Ctx.Git.File.make(ref:path:)),
    review: yaml.review
      .map(Ctx.Sys.Relative.init(value:))
      .reduce(location.ref, Ctx.Git.File.make(ref:path:)),
    fileTaboos: yaml.fileTaboos
      .map(Ctx.Sys.Relative.init(value:))
      .reduce(location.ref, Ctx.Git.File.make(ref:path:)),
    cocoapods: yaml.cocoapods
      .map(Ctx.Sys.Relative.init(value:))
      .reduce(location.ref, Ctx.Git.File.make(ref:path:)),
    production: yaml.flow
      .map(Ctx.Sys.Relative.init(value:))
      .reduce(location.ref, Ctx.Git.File.make(ref:path:)),
    requisition: yaml.requisites
      .map(Ctx.Sys.Relative.init(value:))
      .reduce(location.ref, Ctx.Git.File.make(ref:path:))
  )}
  public func checkSanity(criteria: Criteria?) -> Bool {
    guard let criteria = criteria else { return false }
    guard let codeOwnage = codeOwnage else { return false }
    return criteria.isMet(location.path.value) && criteria.isMet(codeOwnage.path.value)
  }
  public enum Template {
    case name(String)
    case value(String)
    public var name: String {
      switch self {
      case .value(let value): return String(value.prefix(30))
      case .name(let name): return name
      }
    }
    public static func make(yaml: Yaml.Template) throws -> Self {
      guard [yaml.name, yaml.value].compactMap({$0}).count < 2
      else { throw Thrown("Multiple values in template") }
      if let value = yaml.name { return .name(value) }
      else if let value = yaml.value { return .value(value) }
      else { throw Thrown("No values in template") }
    }
  }
}
