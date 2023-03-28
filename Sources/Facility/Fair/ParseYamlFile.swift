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
  var parseReview: Lossy<ParseYamlFile<Review>> { .init(try .init(
    git: git,
    file: profile.review.get(),
    parse: { try .make(yaml: $0.read(Yaml.Review.self, from: $1)) }
  ))}
  var parseSlack: Lossy<ParseYamlFile<Chat.Slack>>? {
    guard let slack = profile.slack else { return nil }
    return .init(.init(
      git: git,
      file: slack,
      parse: { try .make(yaml: $0.read(Yaml.Chat.Slack.self, from: $1)) }
    ))
  }
  var parseRocket: Lossy<ParseYamlFile<Chat.Rocket>>? {
    guard let rocket = profile.rocket else { return nil }
    return .init(.init(
      git: git,
      file: rocket,
      parse: { try .make(yaml: $0.read(Yaml.Chat.Rocket.self, from: $1)) }
    ))
  }
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
    file: profile.cocoapods.get(),
    parse: { try .make(yaml: $0.read(Yaml.Cocoapods.self, from: $1)) }
  ))}
  var parseFileTaboos: Lossy<ParseYamlFile<[FileTaboo]>> { .init(try .init(
    git: git,
    file: profile.fileTaboos.get(),
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
  func parseFlowStorage(
    flow: Flow
  ) -> ParseYamlFile<Flow.Storage> { .init(
    git: git,
    file: .make(asset: flow.storage),
    parse: { try .make(flow: flow, yaml: $0.read(Yaml.Flow.Storage.self, from: $1)) }
  )}
  func parseGitlabStorage(
    asset: Configuration.Asset
  ) -> ParseYamlFile<Gitlab.Storage> { .init(
    git: git,
    file: .make(asset: asset),
    parse: { try .make(asset: asset, yaml: $0.read(Yaml.Gitlab.Storage.self, from: $1)) }
  )}
  func parseReviewStorage(
    review: Review
  ) -> ParseYamlFile<Review.Storage> { .init(
    git: git,
    file: .make(asset: review.storage),
    parse: { try .make(review: review, yaml: $0.read(Yaml.Review.Storage.self, from: $1)) }
  )}
  func parseChatStorage(
    chat: Chat
  ) -> ParseYamlFile<Chat.Storage> { .init(
    git: git,
    file: .make(asset: chat.storage),
    parse: { try .make(chat: chat, yaml: $0.read(Yaml.Chat.Storage.self, from: $1)) }
  )}
}
