import Foundation
import Facility
public protocol ContextLocal {
  var sh: Ctx.Sh { get }
  var repo: Ctx.Repo { get }
}
public protocol ContextSender: ContextLocal {
  func contractReview(_: ContractPayload) throws -> Bool
  func contractProtected(_: ContractPayload) throws -> Bool
  func contract(_: ContractPayload) throws -> Bool
  func triggerProtected(args: [String]) throws -> Bool
  func exportFusion(fork: String, source: String) throws -> Bool
}
public protocol ContextGitlab: ContextSender {
  var gitlab: Ctx.Gitlab { get }
}
public protocol ContextExecutor: ContextLocal {
  var generate: Try.Of<Generate>.Do<String> { get }
  func send(report: Report)
  func execute() throws -> Bool
}
