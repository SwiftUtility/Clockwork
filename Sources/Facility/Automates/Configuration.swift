import Foundation
import Facility
public struct Configuration {
  public var verbose: Bool
  public var git: Git
  public var env: [String: String]
  public var profile: Profile
  public var controls: Controls
  public init(
    verbose: Bool,
    git: Git,
    env: [String : String],
    profile: Profile,
    controls: Controls
  ) {
    self.verbose = verbose
    self.git = git
    self.env = env
    self.profile = profile
    self.controls = controls
  }
  public func get(env key: String) throws -> String {
    try env[key].or { throw Thrown("No \(key) in environment") }
  }
  public struct Profile {
    public var profile: Git.File
    public var controls: Git.File
    public var codeOwnage: Git.File?
    public var fileTaboos: Git.File?
    public var obsolescence: Criteria?
    public var stencilTemplates: [String: String] = [:]
    public static func make(
      profile: Git.File,
      yaml: Yaml.Profile
    ) throws -> Self { try .init(
      profile: profile,
      controls: .init(
        ref: .make(remote: .init(name: yaml.controls.branch)),
        path: .init(value: yaml.controls.file)
      ),
      codeOwnage: yaml.codeOwnage
        .map(Path.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:)),
      fileTaboos: yaml.fileTaboos
        .map(Path.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:)),
      obsolescence: yaml.obsolescence
        .map(Criteria.init(yaml:))
    )}
    public var sanityFiles: [String] {
      [profile, codeOwnage, fileTaboos].compactMap(\.?.path.value)
    }
  }
  public struct Controls {
    public var mainatiners: Set<String>
    public var awardApproval: Git.File?
    public var production: Git.File?
    public var requisition: Git.File?
    public var flow: Git.File?
    public var forbiddenCommits: [Git.Sha]
    public var stencilTemplates: [String: String] = [:]
    public var stencilCustom: AnyCodable?
    public var communication: [String: [Communication]] = [:]
    public var gitlabCi: Lossy<GitlabCi> = .error(Thrown("gitlabCi not configured"))
    public static func make(
      ref: Git.Ref,
      env: [String: String],
      yaml: Yaml.Controls
    ) throws -> Self { try .init(
      mainatiners: .init(yaml.mainatiners.or([])),
      awardApproval: yaml.awardApproval
        .map(Path.Relative.init(value:))
        .reduce(ref, Git.File.init(ref:path:)),
      production: yaml.production
        .map(Path.Relative.init(value:))
        .reduce(ref, Git.File.init(ref:path:)),
      requisition: yaml.requisition
        .map(Path.Relative.init(value:))
        .reduce(ref, Git.File.init(ref:path:)),
      flow: yaml.flow
        .map(Path.Relative.init(value:))
        .reduce(ref, Git.File.init(ref:path:)),
      forbiddenCommits: yaml.forbiddenCommits
        .or([])
        .map(Git.Sha.init(value:))
    )}
  }
}
public extension String {
  func get(env: [String: String]) throws -> String {
    try env[self].or { throw Thrown("No env \(self)") }
  }
}
