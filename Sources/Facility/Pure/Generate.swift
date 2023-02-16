import Foundation
import Facility
public protocol GenerateContext: Encodable {
  static var allowEmpty: Bool { get }
  static var name: String { get }
}
public extension GenerateContext {
  static var allowEmpty: Bool { false }
  static var name: String { "\(Self.self)" }
}
public protocol GenerateInfo: Encodable {
  var event: [String] { get }
  var args: [String]? { get }
  var allowEmpty: Bool { get }
  var env: [String: String] { get set }
  var gitlab: Gitlab.Info? { get set }
  var mark: String? { get set }
  var jira: Jira.Info? { get set }
  var slack: Slack.Info? { get set }
}
public extension GenerateInfo {
  func match(signal: Slack.Signal) -> Bool { signal.events.lazy
    .filter({ event.count <= $0.count })
    .contains(where: { zip(event, $0).contains(where: !=).not })
  }
  func match(create: Slack.Thread) -> Bool { match(signal: create.create) }
  func match(update: Slack.Thread) -> [Slack.Signal] { update.update.filter(match(signal:)) }
}
public struct Generate: Query {
  public var template: Configuration.Template
  public var templates: [String: String]
  public var info: GenerateInfo
  public typealias Reply = String
  public struct Info<Context: GenerateContext>: GenerateInfo {
    public let event: [String]
    public let args: [String]?
    public var ctx: Context
    public var stdin: AnyCodable? = nil
    public var env: [String: String] = [:]
    public var gitlab: Gitlab.Info? = nil
    public var jira: Jira.Info? = nil
    public var slack: Slack.Info? = nil
    public var mark: String? = nil
    public var allowEmpty: Bool { Context.allowEmpty }
    static func make(
      cfg: Configuration,
      context: Context,
      subevent: [String],
      stdin: AnyCodable?,
      args: [String]?
    ) -> Self { .init(
      event: [Context.name] + subevent,
      args: args,
      ctx: context,
      stdin: stdin
    )}
  }
  public struct ExportVersions: GenerateContext {
    public var build: String?
    public var product: String?
    public var versions: [String: String]
  }
  public struct ExportFusion: GenerateContext {
    public var fork: String
    public var source: String
    public var integrate: [String]?
    public var duplicate: [String]?
    public var propogate: [String]?
  }
  public enum BranchKind: String, Encodable {
    case release
    case hotfix
  }
  public struct CreateBranchName: GenerateContext {
    public var product: String
    public var version: String
    public var kind: BranchKind
  }
  public enum TagKind: String, Encodable {
    case deploy
    case stage
  }
  public struct CreateTagName: GenerateContext {
    public var product: String
    public var version: String
    public var build: String
    public var kind: TagKind
  }
  public struct CreateTagAnnotation: GenerateContext {
    public var product: String
    public var version: String
    public var build: String
    public var kind: TagKind
  }
  public struct BumpBuild: GenerateContext {
    public var family: String
    public var build: String
  }
  public struct BumpVersion: GenerateContext {
    public var product: String
    public var version: String
    public var kind: BranchKind
  }
  public struct CreateFlowStorageCommitMessage: GenerateContext {
    public var product: String?
    public var version: String?
    public var build: String?
    public var review: UInt?
    public var branch: String?
    public var tag: String?
    public var reason: Reason
    public enum Reason: String, Encodable {
      case changeNextVersion
      case changeAccessoryVersion
      case createStageTag
      case deleteStageTag
      case createDeployTag
      case deleteDeployTag
      case createReleaseBranch
      case deleteReleaseBranch
      case createAccessoryBranch
      case deleteAccessoryBranch
      case reserveReviewBuild
      case reserveBranchBuild
    }
  }
  public struct CreateGitlabStorageCommitMessage: GenerateContext {
    public var user: String
    public var reason: Reason
    public enum Reason: String, Encodable {
      case activate
      case deactivate
      case register
      case unwatchAuthors
      case unwatchTeams
      case watchAuthors
      case watchTeams
    }
  }
  public struct CreateReviewStorageCommitMessage: GenerateContext {
    public var update: [UInt]? = nil
    public var delete: [UInt]? = nil
    public var enqueue: [UInt]? = nil
    public var dequeue: [UInt]? = nil
  }
  public struct CreateSlackStorageCommitMessage: GenerateContext {
    public var user: String?
    public var reason: Reason
    public enum Reason: String, Encodable {
      case registerUser
      case createThreads
    }
  }
  public struct CreateMergeTitle: GenerateContext {
    public var kind: String
    public var fork: String
    public var original: String
    public var target: String
  }
  public struct CreateMergeCommit: GenerateContext {
    public var kind: String
    public var merge: Json.GitlabMergeState
    public var fork: String
    public var original: String
  }
  public struct CreateSquashCommit: GenerateContext {
    public var kind: String
    public var merge: Json.GitlabMergeState
  }
}
public extension Configuration {
  func report(template: Configuration.Template, info: GenerateInfo) -> Generate {
    .init(template: template, templates: templates, info: info)
  }
  func exportVersions(
    flow: Flow,
    stdin: AnyCodable?,
    args: [String],
    versions: [String: String],
    build: String?,
    product: String?
  ) -> Generate { generate(
    template: flow.exportVersions,
    ctx: Generate.ExportVersions(
      build: build,
      product: product,
      versions: versions
    ),
    stdin: stdin,
    args: args
  )}
  func createFlowStorageCommitMessage(
    flow: Flow,
    reason: Generate.CreateFlowStorageCommitMessage.Reason,
    product: String? = nil,
    version: String? = nil,
    build: String? = nil,
    review: UInt? = nil,
    branch: String? = nil,
    tag: String? = nil
  ) -> Generate { generate(
    template: flow.storage.createCommitMessage,
    ctx: Generate.CreateFlowStorageCommitMessage(
      product: product,
      version: version,
      build: build,
      review: review,
      branch: branch,
      tag: tag,
      reason: reason
    ),
    subevent: [reason.rawValue]
  )}
  func bumpBuild(
    flow: Flow,
    family: Flow.Family
  ) -> Generate { generate(
    template: flow.bumpBuild,
    ctx: Generate.BumpBuild(family: family.name, build: family.nextBuild.value)
  )}
  func createTagName(
    flow: Flow,
    product: String,
    version: AlphaNumeric,
    build: AlphaNumeric,
    kind: Generate.TagKind
  ) -> Generate { generate(
    template: flow.createTagName,
    ctx: Generate.CreateTagName(
      product: product,
      version: version.value,
      build: build.value,
      kind: kind
    ),
    subevent: [kind.rawValue]
  )}
  func createTagAnnotation(
    flow: Flow,
    product: String,
    version: AlphaNumeric,
    build: AlphaNumeric,
    kind: Generate.TagKind
  ) -> Generate { generate(
    template: flow.createTagAnnotation,
    ctx: Generate.CreateTagAnnotation(
      product: product,
      version: version.value,
      build: build.value,
      kind: kind
    ),
    subevent: [kind.rawValue]
  )}
  func createReleaseBranchName(
    flow: Flow,
    product: String,
    version: AlphaNumeric,
    kind: Generate.BranchKind
  ) -> Generate { generate(
    template: flow.createReleaseBranchName,
    ctx: Generate.CreateBranchName(
      product: product,
      version: version.value,
      kind: kind
    ),
    subevent: [kind.rawValue]
  )}
  func bumpVersion(
    flow: Flow,
    product: String,
    version: AlphaNumeric,
    kind: Generate.BranchKind
  ) -> Generate { generate(
    template: flow.bumpVersion,
    ctx: Generate.BumpVersion(product: product, version: version.value, kind: kind),
    subevent: [kind.rawValue]
  )}
  func createGitlabStorageCommitMessage(
    user: String,
    gitlab: Gitlab,
    reason: Generate.CreateGitlabStorageCommitMessage.Reason
  ) -> Generate { generate(
    template: gitlab.storage.asset.createCommitMessage,
    ctx: Generate.CreateGitlabStorageCommitMessage(user: user, reason: reason),
    subevent: [reason.rawValue]
  )}
  func createReviewStorageCommitMessage(
    review: Review,
    context: Generate.CreateReviewStorageCommitMessage
  ) -> Generate { generate(
    template: review.storage.createCommitMessage,
    ctx: context
  )}
  func createSlackStorageCommitMessage(
    slack: Slack,
    user: String?,
    reason: Generate.CreateSlackStorageCommitMessage.Reason
  ) -> Generate { generate(
    template: slack.storage.createCommitMessage,
    ctx: Generate.CreateSlackStorageCommitMessage(user: user, reason: reason),
    subevent: [reason.rawValue]
  )}
  func createSquashCommitMessage(
    merge: Json.GitlabMergeState,
    review: Review,
    fusion: Review.Fusion
  ) -> Generate? {
    guard fusion.proposition else { return nil }
    return generate(
      template: review.createSquashCommit,
      ctx: Generate.CreateSquashCommit(
        kind: fusion.kind,
        merge: merge
      ),
      subevent: [fusion.kind]
    )
  }
  func createMergeCommitMessage(
    merge: Json.GitlabMergeState,
    review: Review,
    fusion: Review.Fusion
  ) -> Generate? {
    guard fusion.propogation.not, let fork = fusion.fork, let original = fusion.original
    else { return nil }
    return generate(
      template: review.createMergeCommit,
      ctx: Generate.CreateMergeCommit(
        kind: fusion.kind,
        merge: merge,
        fork: fork.value,
        original: original.name
      ),
      subevent: [fusion.kind]
    )
  }
  func createMergeTitle(
    review: Review,
    fusion: Review.Fusion
  ) throws -> Generate {
    guard let fork = fusion.fork, let original = fusion.original
    else { throw Thrown("Inconsistency") }
    return generate(
      template: review.createMergeTitle,
      ctx: Generate.CreateMergeTitle(
        kind: fusion.kind,
        fork: fork.value,
        original: original.name,
        target: fusion.target.name
      ),
      subevent: [fusion.kind]
    )
  }
  func exportTargets(
    review: Review,
    fork: Git.Sha,
    source: String,
    integrate: [String],
    duplicate: [String],
    propogate: [String],
    stdin: AnyCodable?,
    args: [String]
  ) -> Generate { generate(
    template: review.exportTargets,
    ctx: Generate.ExportFusion(
      fork: fork.value,
      source: source,
      integrate: integrate.isEmpty.not.then(integrate),
      duplicate: duplicate.isEmpty.not.then(duplicate),
      propogate: propogate.isEmpty.not.then(propogate)
    ),
    stdin: stdin,
    args: args.isEmpty.else(args)
  )}
}
private extension Configuration {
  func generate<Context: GenerateContext>(
    template: Configuration.Template,
    ctx: Context,
    subevent: [String] = [],
    stdin: AnyCodable? = nil,
    args: [String]? = nil
  ) -> Generate {
    var info = Generate.Info.make(
      cfg: self,
      context: ctx,
      subevent: subevent,
      stdin: stdin,
      args: args
    )
    info.env = env
    info.gitlab = try? gitlab.get().info
    info.jira = try? jira.get().info
    info.stdin = stdin
    return .init(template: template, templates: templates, info: info)
  }
}
