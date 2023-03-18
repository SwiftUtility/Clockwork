import Foundation
import Facility
public protocol ContextCommon {
  var sh: Ctx.Sh { get }
  var git: Ctx.Git { get }
  var repo: Ctx.Repo { get }
}
public protocol ContextLocal: ContextCommon {
  var generate: Try.Of<Generate>.Do<String> { get }
  func gitlab() throws -> ContextGitlab
  func exclusive(parent: UInt) throws -> ContextExclusive
}
public protocol ContextGitlab: ContextCommon {
  var gitlab: Ctx.Gitlab { get }
  func protected() throws -> ContextProtected
}
public protocol ContextProtected: ContextGitlab {
  var rest: String { get }
  var project: Json.GitlabProject { get }
}
public protocol ContextExclusive: ContextProtected {
  var bot: Json.GitlabUser { get }
  var parent: Json.GitlabJob { get }
  var storage: Ctx.Storage { get }
  var generate: Try.Of<Generate>.Do<String> { get }
  func send(report: Report)
  func getFlow() throws -> Flow
}
