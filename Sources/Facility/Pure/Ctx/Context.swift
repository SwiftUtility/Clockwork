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
  func exclusive() throws -> ContextExclusive
}
public protocol ContextGitlab: Context {
  var gitlab: Ctx.Gitlab { get }
  func protected() throws -> Ctx.Gitlab.Protected
}
public protocol ContextExclusive: Context {
  var gitlab: Ctx.Gitlab { get }
  var protected: Ctx.Gitlab.Protected { get }
  var generate: Try.Of<Generate>.Do<String> { get }
  func send(report: Report)
}
