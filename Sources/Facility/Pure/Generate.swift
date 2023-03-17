import Foundation
import Facility
public protocol GenerateContext: Encodable {
  static var name: String { get }
}
public extension GenerateContext {
  static var name: String { "\(Self.self)" }
}
public protocol GenerateInfo: Encodable {
  var event: [String] { get }
  var env: [String: String] { get set }
  var gitlab: Gitlab.Info? { get set }
  var mark: String? { get set }
  var jira: Jira.Info? { get set }
  var chat: Chat.Info? { get set }
}
public extension GenerateInfo {
  func match(events: [[String]]) -> Bool { events.lazy
    .filter({ event.count >= $0.count })
    .contains(where: { zip(event, $0).contains(where: !=).not })
  }
  func match(chat: Chat.Diffusion.Signal) -> Bool { match(events: chat.events) }
  func match(create: Chat.Diffusion.Thread) -> Bool { match(chat: create.create) }
  func match(update: Chat.Diffusion.Thread) -> [Chat.Diffusion.Signal] {
    update.update.filter(match(chat:))
  }
  func match(chain: Jira.Chain) -> Bool { match(events: chain.events) }
  func match(note: Gitlab.Note) -> Bool { match(events: note.events) }
}
public struct Generate: Query {
  public var template: Configuration.Template
  public var allowEmpty: Bool
  public var info: GenerateInfo
  public static func make(
    template: String,
    stdin: AnyCodable?,
    args: [String],
    env: [String: String]
  ) -> Generate { .init(
    template: .name(template),
    allowEmpty: false,
    info: Generate.Info.init(
      event: [],
      args: args,
      ctx: Generate.Render(template: template),
      stdin: stdin,
      env: env
    )
  )}
  public typealias Reply = String
  public struct Info<Context: GenerateContext>: GenerateInfo {
    public let event: [String]
    public let args: [String]?
    public var ctx: Context
    public var stdin: AnyCodable? = nil
    public var env: [String: String] = [:]
    public var gitlab: Gitlab.Info? = nil
    public var jira: Jira.Info? = nil
    public var chat: Chat.Info? = nil
    public var mark: String? = nil
    static func make(
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
    public var user: String?
    public var reviews: [String]?
    public var reason: Reason
    public enum Reason: String, Encodable {
      case activateUser
      case deactivateUser
      case registerUser
      case updateUserWatchList
      case updateReviews
      case cleanReviews
    }
  }
  public struct CreateReviewStorageCommitMessage: GenerateContext {
    public var update: [UInt]? = nil
    public var delete: [UInt]? = nil
    public var enqueue: [UInt]? = nil
    public var dequeue: [UInt]? = nil
  }
  public struct CreateChatStorageCommitMessage: GenerateContext {
    public var user: String?
    public var kind: Chat.Kind
    public var reason: Reason
    public enum Reason: String, Encodable {
      case registerUser
      case createThreads
      case cleanThreads
    }
  }
  public struct CreateMergeTitle: GenerateContext {
    public var kind: String
    public var fork: String
    public var fusion: String
    public var target: String
  }
  public struct CreatePatchCommit: GenerateContext {
    public var merge: Json.GitlabMerge
  }
  public struct CreateMergeCommit: GenerateContext {
    public var kind: String
    public var merge: Json.GitlabMerge
    public var fork: String
    public var fusion: String
  }
  public struct CreateSquashCommit: GenerateContext {
    public var kind: String
    public var merge: Json.GitlabMerge
  }
  public struct Render: GenerateContext {
    public var template: String
  }
}
public extension Configuration {
  func report(template: Configuration.Template, info: GenerateInfo) -> Generate { .init(
    template: template, allowEmpty: true, info: info
  )}
  func render(template: String, stdin: AnyCodable?, args: [String]) -> Generate { generate(
    template: .name(template),
    ctx: Generate.Render(template: template),
    stdin: stdin,
    args: args
  )}
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
    user: String?,
    reviews: [String],
    gitlab: Gitlab,
    reason: Generate.CreateGitlabStorageCommitMessage.Reason
  ) -> Generate { generate(
    template: gitlab.storage.asset.createCommitMessage,
    ctx: Generate.CreateGitlabStorageCommitMessage(
      user: user,
      reviews: reviews.sorted().notEmpty,
      reason: reason
    ),
    subevent: [reason.rawValue]
  )}
  func createReviewStorageCommitMessage(
    review: Review,
    context: Generate.CreateReviewStorageCommitMessage
  ) -> Generate { generate(
    template: review.storage.createCommitMessage,
    ctx: context
  )}
  func createChatStorageCommitMessage(
    chat: Chat,
    user: String?,
    reason: Generate.CreateChatStorageCommitMessage.Reason
  ) -> Generate { generate(
    template: chat.storage.createCommitMessage,
    ctx: Generate.CreateChatStorageCommitMessage(user: user, kind: chat.kind, reason: reason),
    subevent: [reason.rawValue, chat.kind.rawValue]
  )}
  func createSquashCommitMessage(
    merge: Json.GitlabMerge,
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
    merge: Json.GitlabMerge,
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
        fusion: original.name
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
        fusion: original.name,
        target: fusion.target.name
      ),
      subevent: [fusion.kind]
    )
  }
  func createPatchCommitMessage(
    merge: Json.GitlabMerge,
    review: Review
  ) throws -> Generate { generate(
    template: review.createPatchCommit,
    ctx: Generate.CreatePatchCommit(merge: merge)
  )}
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
      context: ctx,
      subevent: subevent,
      stdin: stdin,
      args: args
    )
    info.env = env
    info.gitlab = try? gitlab.get().info
    info.jira = try? jira.get().info
    info.stdin = stdin
    return .init(template: template, allowEmpty: false, info: info)
  }
}
