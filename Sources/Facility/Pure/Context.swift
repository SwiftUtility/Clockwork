import Foundation
import Facility
public protocol Context {
  var sh: Ctx.Sh { get }
  var git: Ctx.Git { get }
  var repo: Ctx.Repo { get }
}
public protocol ContextLocal: Context {
  var generate: Try.Of<Generate>.Do<String> { get }
  func gitlab() throws -> ContextGitlab
  func exclusive(parent: UInt) throws -> ContextExclusive
}
public protocol ContextGitlab: Context {
  var gitlab: Ctx.Gitlab { get }
  func protected() throws -> ContextGitlabProtected
}
public protocol ContextGitlabProtected: ContextGitlab {
  var rest: String { get }
  var project: Json.GitlabProject { get }
}
public protocol ContextExclusive: ContextGitlabProtected {
  var storage: Ctx.Storage { get }
  var parent: Json.GitlabJob { get }
  var generate: Try.Of<Generate>.Do<String> { get }
  func send(report: Report)
  func getFlow() throws -> Flow
}
