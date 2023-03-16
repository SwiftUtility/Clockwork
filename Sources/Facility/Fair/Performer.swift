import Foundation
import Facility
import FacilityPure
public protocol Performer {
  func perform(repo: ContextLocal) throws -> Bool
}
public protocol GitlabPerformer: Performer {
  func perform(gitlab: ContextGitlab) throws -> Bool
}
public extension GitlabPerformer {
  func perform(repo: ContextLocal) throws -> Bool {
    try perform(gitlab: repo.gitlab())
  }
}
public protocol ProtectedGitlabPerformer: GitlabPerformer {
  func perform(protected: ContextGitlabProtected) throws -> Bool
}
public extension ProtectedGitlabPerformer {
  func perform(gitlab ctx: ContextGitlab) throws -> Bool {
    try perform(protected: ctx.protected())
  }
}
public protocol ContractPerformer: Codable, GitlabPerformer {
  static var subject: String { get }
  static var triggerContract: Bool { get }
  mutating func perform(exclusive: ContextExclusive) throws
  func checkContract(ctx: ContextGitlabProtected) throws
}
public extension ContractPerformer {
  static var triggerContract: Bool { false }
  func perform(gitlab ctx: ContextGitlab) throws -> Bool {
    let variables = try Contract.pack(ctx: ctx, payload: self)
    if ctx.gitlab.current.isReview {
      try ctx.triggerPipeline(ref: ctx.gitlab.cfg.contract.ref.value, variables: variables)
    } else {
      let protected = try ctx.protected()
      try protected.createPipeline(
        ref: Self.triggerContract
          .then(ctx.gitlab.cfg.contract.ref.value)
          .get(protected.project.defaultBranch),
        variables: variables
      )
    }
    return true
  }
  func checkContract(ctx: ContextGitlabProtected) throws {
    let ref = (Self.triggerContract || ctx.gitlab.current.isReview)
      .then(ctx.gitlab.cfg.contract.name)
      .get(ctx.project.defaultBranch)
    guard ref == ctx.gitlab.current.pipeline.ref
    else { throw Thrown("Must be triggered on \(ref)") }
  }
  static var subject: String { "\(Self.self)" }
}
public protocol ProtectedContractPerformer: ContractPerformer {}
public extension ProtectedContractPerformer {
  func perform(gitlab ctx: ContextGitlab) throws -> Bool {
    let variables = try Contract.pack(ctx: ctx, payload: self)
    let protected = try ctx.protected()
    try protected.createPipeline(
      ref: Self.triggerContract
        .then(ctx.gitlab.cfg.contract.ref.value)
        .get(protected.project.defaultBranch),
      variables: variables
    )
    return true
  }
}
public protocol ReviewContractPerformer: ContractPerformer {}
public extension ReviewContractPerformer {
  func perform(gitlab ctx: ContextGitlab) throws -> Bool {
    let variables = try Contract.pack(ctx: ctx, payload: self)
    guard ctx.gitlab.current.isReview else { throw Thrown("Not review job") }
    try ctx.triggerPipeline(ref: ctx.gitlab.cfg.contract.ref.value, variables: variables)
    return true
  }
}
