import Foundation
import Facility
public protocol ContextShell {
  var sh: Ctx.Sh { get }
  var git: Ctx.Git { get }
  var repo: Ctx.Repo { get }
}
public protocol ContextRepo: ContextShell {
  var generate: Try.Of<Generate>.Do<String> { get }
  func gitlab() throws -> ContextGitlab
  func exclusive() throws -> ContextExclusive
}
public protocol ContextGitlab: ContextShell {
  var gitlab: Ctx.Gitlab { get }
  func protected() throws -> Ctx.Gitlab.Protected
}
public protocol ContextExclusive: ContextShell {
  var gitlab: Ctx.Gitlab { get }
  var protected: Ctx.Gitlab.Protected { get }
  var generate: Try.Of<Generate>.Do<String> { get }
  func send(report: Report)
}
