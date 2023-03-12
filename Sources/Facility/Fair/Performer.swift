import Foundation
import Facility
import FacilityPure
public protocol Performer {
  func perform(repo: ContextRepo) throws -> Bool
}
public protocol GitlabPerformer: Performer {
  func perform(gitlab: ContextGitlab) throws -> Bool
}
public extension GitlabPerformer {
  func perform(repo: ContextRepo) throws -> Bool {
    try perform(gitlab: repo.gitlab())
  }
}
public protocol ProtectedGitlabPerformer: GitlabPerformer {
  func perform(gitlab: ContextGitlab, protected: Ctx.Gitlab.Protected) throws -> Bool
}
public extension ProtectedGitlabPerformer {
  func perform(gitlab ctx: ContextGitlab) throws -> Bool {
    try perform(gitlab: ctx, protected: ctx.protected())
  }
}
public protocol ContractPerformer: Codable, GitlabPerformer {
  static var subject: String { get }
  func perform(exclusive: ContextExclusive) throws -> Bool
}
public extension ContractPerformer {
  func perform(gitlab ctx: ContextGitlab) throws -> Bool {
    let variables = try Contract.pack(
      job: ctx.gitlab.current.id,
      version: ctx.repo.profile.version,
      payload: self,
      encoder: ctx.sh.rawEncoder
    )
    if ctx.gitlab.current.isReview {
      try ctx.triggerPipeline(ref: ctx.gitlab.cfg.contract.ref.value, variables: variables)
    } else {
      let protected = try ctx.protected()
      try ctx.createPipeline(protected: protected, variables: variables)
    }
    return true
  }
  func perform(exclusive: ContextExclusive) throws -> Bool {
    #warning("TBD")
    return false
  }
  static var subject: String { "\(Self.self)" }
}
public protocol ProtectedContractPerformer: ContractPerformer {}
public extension ProtectedContractPerformer {
  func perform(gitlab ctx: ContextGitlab) throws -> Bool {
    let variables = try Contract.pack(
      job: ctx.gitlab.current.id,
      version: ctx.repo.profile.version,
      payload: self,
      encoder: ctx.sh.rawEncoder
    )
    let protected = try ctx.protected()
    try ctx.createPipeline(protected: protected, variables: variables)
    return true
  }
}
public protocol ReviewContractPerformer: ContractPerformer {}
public extension ReviewContractPerformer {
  func perform(gitlab ctx: ContextGitlab) throws -> Bool {
    let variables = try Contract.pack(
      job: ctx.gitlab.current.id,
      version: ctx.repo.profile.version,
      payload: self,
      encoder: ctx.sh.rawEncoder
    )
    guard ctx.gitlab.current.isReview else { throw Thrown("Not review job") }
    try ctx.triggerPipeline(ref: ctx.gitlab.cfg.contract.ref.value, variables: variables)
    return true
  }
}
