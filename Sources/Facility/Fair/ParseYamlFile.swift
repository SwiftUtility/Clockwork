import Foundation
import Facility
import FacilityPure
public struct ParseYamlFile<T>: Query {
  public var git: Git
  public var file: Git.File
  public var parse: Try.Of<AnyCodable.Dialect>.Of<AnyCodable>.Do<T>
  public typealias Reply = T
}
public extension Configuration {
  var parseFusion: Lossy<ParseYamlFile<Fusion>> { .init(try .init(
    git: git,
    file: profile.fusion.get(),
    parse: { try .make(yaml: $0.read(Yaml.Review.self, from: $1)) }
  ))}
  var parseFlow: Lossy<ParseYamlFile<Flow>> { .init(try .init(
    git: git,
    file: profile.production.get(),
    parse: { try .make(yaml: $0.read(Yaml.Flow.self, from: $1)) }
  ))}
  var parseRequisition: Lossy<ParseYamlFile<Requisition>> { .init(try .init(
    git: git,
    file: profile.requisition.get(),
    parse: { try .make(env: env, yaml: $0.read(Yaml.Requisition.self, from: $1)) }
  ))}
  var parseCocoapods: Lossy<ParseYamlFile<Cocoapods>> { .init(try .init(
    git: git,
    file: profile.requisition.get(),
    parse: { try .make(yaml: $0.read(Yaml.Cocoapods.self, from: $1)) }
  ))}
  var parseFileTaboos: Lossy<ParseYamlFile<[FileTaboo]>> { .init(try .init(
    git: git,
    file: profile.requisition.get(),
    parse: { try $0.read([Yaml.FileTaboo].self, from: $1).map(FileTaboo.init(yaml:)) }
  ))}
  func parseCodeOwnage(
    profile: Configuration.Profile
  ) -> ParseYamlFile<[String: Criteria]>? {
    guard let codeOwnage = profile.codeOwnage else { return nil }
    return .init(.init(
      git: git,
      file: codeOwnage,
      parse: { try $0.read([String: Yaml.Criteria].self, from: $1).mapValues(Criteria.init(yaml:)) }
    ))
  }
  func parseProfile(
    ref: Git.Ref
  ) -> ParseYamlFile<Configuration.Profile> {
    let profile = Git.File(ref: ref, path: profile.location.path)
    return .init(git: git, file: profile, parse: {
      try .make(location: profile, yaml: $0.read(Yaml.Profile.self, from: $1))
    })
  }
  func parseFlowBuilds(
    builds: Flow.Builds
  ) -> ParseYamlFile<Flow.Builds.Storage> { .init(
    git: git,
    file: .make(asset: builds.storage),
    parse: { try .make(yaml: $0.read(Yaml.Flow.Builds.Storage.self, from: $1)) }
  )}
  func parseFlowVersions(
    flow: Flow
  ) -> ParseYamlFile<Flow.Versions.Storage> { .init(
    git: git,
    file: .make(asset: flow.versions.storage),
    parse: { try .make(yaml: $0.read(Yaml.Flow.Versions.Storage.self, from: $1)) }
  )}
  func parseFusionStatuses(
    approval: Fusion.Approval
  ) -> ParseYamlFile<[UInt: Fusion.Approval.Status]> { .init(
    git: git,
    file: .make(asset: approval.statuses),
    parse: { dialect, yaml in try dialect
      .read([String: Yaml.Review.Approval.Status].self, from: yaml)
      .map(Fusion.Approval.Status.make(review:yaml:))
      .reduce(into: [:], { $0[$1.review] = $1 })
    }
  )}
  func parseGitlabUsers(
    gitlab: Gitlab
  ) -> ParseYamlFile<[String: Gitlab.User]> { .init(
    git: git,
    file: .make(asset: gitlab.usersAsset),
    parse: { dialect, yaml in try dialect
      .read([String: Yaml.Gitlab.User].self, from: yaml)
      .map(Gitlab.User.make(login:yaml:))
      .reduce(into: [:], { $0[$1.login] = $1 })
    }
  )}
  func parseReviewQueue(
    fusion: Fusion
  ) -> ParseYamlFile<Fusion.Queue> { .init(
    git: git,
    file: .make(asset: fusion.queue),
    parse: { try .make(fusion: fusion, queue: $0.read([String: [UInt]].self, from: $1)) }
  )}
  func parseSlackStorage(
    slack: Slack
  ) -> ParseYamlFile<Slack.Storage> { .init(
    git: git,
    file: .make(asset: slack.storage),
    parse: { try .make(yaml: $0.read(Yaml.Slack.Storage.self, from: $1)) }
  )}
}
