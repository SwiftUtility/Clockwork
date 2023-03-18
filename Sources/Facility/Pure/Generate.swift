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
  var gitlab: Ctx.Gitlab.Info? { get set }
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
  public var template: Ctx.Template
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
    public var gitlab: Ctx.Gitlab.Info? = nil
    public var jira: Jira.Info? = nil
    public var chat: Chat.Info? = nil
    public var mark: String? = nil
    public static func make(
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
public extension ContextExclusive {
  func generateBuildBump(
    flow: Flow,
    family: Flow.Family
  ) throws -> String { try make(
    template: flow.bumpBuild,
    ctx: Generate.BumpBuild(family: family.name, build: family.nextBuild.value)
  )}
  func generateReleaseBranchName(
    flow: Flow,
    product: String,
    version: AlphaNumeric,
    kind: Generate.BranchKind
  ) throws -> String { try make(
    template: flow.createReleaseBranchName,
    ctx: Generate.CreateBranchName(
      product: product,
      version: version.value,
      kind: kind
    ),
    subevent: [kind.rawValue]
  )}
  func generateTagName(
    flow: Flow,
    product: String,
    version: AlphaNumeric,
    build: AlphaNumeric,
    kind: Generate.TagKind
  ) throws -> String { try make(
    template: flow.createTagName,
    ctx: Generate.CreateTagName(
      product: product,
      version: version.value,
      build: build.value,
      kind: kind
    ),
    subevent: [kind.rawValue]
  )}
  func generateTagAnnotation(
    flow: Flow,
    product: String,
    version: AlphaNumeric,
    build: AlphaNumeric,
    kind: Generate.TagKind
  ) throws -> String { try make(
    template: flow.createTagAnnotation,
    ctx: Generate.CreateTagAnnotation(
      product: product,
      version: version.value,
      build: build.value,
      kind: kind
    ),
    subevent: [kind.rawValue]
  )}
  func generateVersionBump(
    flow: Flow,
    product: String,
    version: AlphaNumeric,
    kind: Generate.BranchKind
  ) throws -> String { try make(
    template: flow.bumpVersion,
    ctx: Generate.BumpVersion(product: product, version: version.value, kind: kind),
    subevent: [kind.rawValue]
  )}
  func generateSquashCommitMessage(
    merge: Json.GitlabMerge,
    review: Review,
    fusion: Review.Fusion
  ) throws -> String? {
    guard fusion.proposition else { return nil }
    return try make(
      template: review.createSquashCommit,
      ctx: Generate.CreateSquashCommit(
        kind: fusion.kind,
        merge: merge
      ),
      subevent: [fusion.kind]
    )
  }
  func generateMergeCommitMessage(
    merge: Json.GitlabMerge,
    review: Review,
    fusion: Review.Fusion
  ) throws -> String? {
    guard fusion.propogation.not, let fork = fusion.fork, let original = fusion.original
    else { return nil }
    return try make(
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
  func generateMergeTitle(
    review: Review,
    fusion: Review.Fusion
  ) throws -> String {
    guard let fork = fusion.fork, let original = fusion.original
    else { throw Thrown("Inconsistency") }
          return try make(
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
  func generatePatchCommitMessage(
    merge: Json.GitlabMerge,
    review: Review
  ) throws -> String { try make(
    template: review.createPatchCommit,
    ctx: Generate.CreatePatchCommit(merge: merge)
  )}
}
private extension ContextExclusive {
  func make<Context: GenerateContext>(
    template: Ctx.Template,
    ctx: Context,
    subevent: [String] = [],
    stdin: AnyCodable? = nil,
    args: [String]? = nil
  ) throws -> String {
    var info = Generate.Info.make(
      context: ctx,
      subevent: subevent,
      stdin: stdin,
      args: args
    )
    info.env = sh.env
#warning("TBD set gitlab, jira")
    return try generate(.init(template: template, allowEmpty: false, info: info))
  }
}
