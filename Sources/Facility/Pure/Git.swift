import Foundation
import Facility
public struct Git {
  public var root: Files.Absolute
  public var lfs: Bool = false
  public var env: [String: String]
  public init(env: [String: String], root: Files.Absolute) throws {
    self.root = root
    self.env = env
  }
  public struct File: Hashable {
    public var ref: Ref
    public var path: Files.Relative
    public init(ref: Ref, path: Files.Relative) {
      self.ref = ref
      self.path = path
    }
    public static func make(asset: Configuration.Asset) -> Self { .init(
      ref: .make(remote: asset.branch),
      path: asset.file
    )}
  }
  public struct Dir {
    public var ref: Ref
    public var path: Files.Relative
    public init(ref: Ref, path: Files.Relative) {
      self.ref = ref
      self.path = path
    }
  }
  public struct Ref: Hashable {
    public let value: String
    public var tree: Tree { .init(ref: self) }
    public func make(parent number: Int) throws -> Self {
      guard number > 0 else { throw MayDay("commit parent must be > 0") }
      return .init(value: "\(value)^\(number)")
    }
    public static var head: Self { .init(value: "HEAD") }
    public static func make(sha: Sha) -> Self {
      return .init(value: sha.value)
    }
    public static func make(tag: String) throws -> Self {
      guard !tag.isEmpty else { throw Thrown("tag is empty") }
      return .init(value: "refs/tags/\(tag)")
    }
    public static func make(remote branch: Branch) -> Self {
      return .init(value: "refs/remotes/origin/\(branch.name)")
    }
    public static func make(local branch: Branch) -> Self {
      return .init(value: "refs/heads/\(branch.name)")
    }
  }
  public struct Sha: Hashable {
    public let value: String
    public static func make(value: String) throws -> Self {
      try validate(sha: value)
      return .init(value: value)
    }
    public static func make(job: Json.GitlabJob) throws -> Self {
      try validate(sha: job.pipeline.sha)
      return .init(value: job.pipeline.sha)
    }
    static func validate(sha: String) throws {
      guard sha.count == 40, sha.trimmingCharacters(in: .hexadecimalDigits).isEmpty else {
        throw Thrown("Not sha: \(sha)")
      }
    }
  }
  public struct Tree {
    public let value: String
    public init(ref: Ref) {
      self.value = "\(ref.value)^{tree}"
    }
    public init(sha: String) throws {
      self.value = try Sha.make(value: sha).value
    }
  }
  public struct Branch {
    public let name: String
    public init(name: String) throws {
      guard
        !name.isEmpty,
        !name.hasPrefix("/"),
        !name.hasSuffix("/"),
        !name.contains(" ")
      else { throw Thrown("invalid branch name") }
      self.name = name
    }
    public static func make(job: Json.GitlabJob) throws -> Self {
      guard job.tag.not else { throw Thrown("Not branch job \(job.webUrl)") }
      return try .init(name: job.pipeline.ref)
    }
  }
}
public extension Git {
  func listChangedFiles(source: Ref, target: Ref) -> Execute { proc(
    args: ["diff", "--name-only", "--merge-base", target.value, source.value]
  )}
  var listConflictMarkers: Execute { proc(
    args: [
      "-c", "core.whitespace=" + [
        "-trailing-space", "-space-before-tab", "-indent-with-non-tab",
        "-tab-in-indent", "-cr-at-eol",
      ].joined(separator: ","),
      "diff", "--check", "HEAD"
    ],
    escalate: false
  )}
  var changesList: Execute { proc(args: ["status", "--porcelain"]) }
  var listLocalChanges: Execute { proc(args: ["diff", "--name-only", "HEAD"]) }
  var listAllRefs: Execute { proc(args: ["show-ref", "--head"]) }
  func excludeParents(shas: Set<Git.Sha>) -> Execute { proc(
    args: ["show-branch", "--independent"] + shas.map(\.value)
  )}
  func check(child: Ref, parent: Ref) -> Execute { proc(
    args: ["merge-base", "--is-ancestor", parent.value, child.value]
  )}
  func detach(ref: Ref) -> Execute { proc(
    args: ["checkout", "--force", "--detach", ref.value]
  )}
  func listChangedOutsideFiles(source: Ref, target: Ref) -> Execute { proc(
    args: ["diff", "--name-only", "\(source.value)...\(target.value)"]
  )}
  func listAllTrackedFiles(ref: Ref) -> Execute { proc(
    args: ["ls-tree", "-r", "--name-only", "--full-tree", ref.value, "."]
  )}
  func listTreeTrackedFiles(dir: Dir) -> Execute { proc(
    args: ["ls-tree", "-r", "--name-only", "--full-tree", dir.ref.value, dir.path.value]
  )}
  func checkObjectType(ref: Ref) -> Execute { proc(args: ["cat-file", "-t", ref.value]) }
  func listCommits(
    in include: [Ref],
    notIn exclude: [Ref],
    noMerges: Bool = false,
    firstParents: Bool = false,
    boundary: Bool = false,
    ignoreMissing: Bool = false
  ) -> Execute { proc(
    args: ["log", "--format=%H"] + [
      boundary.then("--boundary"),
      firstParents.then("--first-parent"),
      noMerges.then("--no-merges"),
      ignoreMissing.then("--ignore-missing"),
    ].compactMap({ $0 }) + include.map(\.value) + exclude.map({ "^\($0.value)" })
  )}
  var writeTree: Execute { proc(args: ["write-tree"]) }
  func commitTree(
    tree: Tree,
    message: String,
    parents: [Ref],
    env: [String: String]
  ) -> Execute { proc(
    args: ["commit-tree", tree.value, "-m", message] + parents.flatMap { ["-p", $0.value] },
    env: env
  )}
  func getAuthorName(ref: Ref) -> Execute { proc(
    args: ["show", "-s", "--format=%aN", ref.value]
  )}
  func getAuthorEmail(ref: Ref) -> Execute { proc(
    args: ["show", "-s", "--format=%aE", ref.value]
  )}
  func getAuthorTimestamp(ref: Ref) -> Execute { proc(
    args: ["show", "-s", "--format=%at", ref.value]
  )}
  func getCommitMessage(ref: Ref) -> Execute { proc(
    args: ["show", "-s", "--format=%B", ref.value]
  )}
  func listParents(ref: Ref) -> Execute { proc(
    args: ["rev-parse", "\(ref.value)^@"]
  )}
  func mergeBase(_ one: Ref, _ two: Ref) -> Execute { proc(
    args: ["merge-base", one.value, two.value]
  )}
  func push(url: String, branch: Branch, sha: Sha, force: Bool) -> Execute { proc(
    args: ["push", url]
    + force.then(["--force"]).get([])
    + ["\(sha.value):\(Ref.make(local: branch).value)"]
  )}
  func push(url: String, delete branch: Branch) -> Execute { proc(
    args: ["push", url, ":\(Ref.make(local: branch))"]
  )}
  var updateLfs: Execute { proc(args: ["lfs", "update"]) }
  var fetch: Execute { proc(
    args: ["fetch", "origin", "--prune", "--prune-tags", "--tags", "--force"]
  )}
  func fetchBranch(_ branch: Branch) -> Execute { proc(
    args: ["fetch", "origin", Ref.make(local: branch).value, "--no-tags"]
  )}
  func cat(file: File) throws -> Execute {
    var result = proc(args: ["show", "\(file.ref.value):\(file.path.value)"])
    result.tasks += lfs.then(proc(args: ["lfs", "smudge"])).map(\.tasks).get([])
    return result
  }
  var userName: Execute { proc(args: ["config", "user.name"]) }
  func getSha(ref: Ref) -> Execute { proc(args: ["rev-parse", ref.value]) }
  var getOriginUrl: Execute { proc(args: ["config", "--get", "remote.origin.url"]) }
  func create(branch: Branch, at sha: Sha) -> Execute { proc(
    args: ["checkout", "-B", branch.name, sha.value]
  )}
  var clean: Execute { proc(args: ["clean", "-fdx"]) }
  func merge(
    refs: [Ref],
    message: String?,
    noFf: Bool,
    env: [String: String] = [:],
    escalate: Bool
  ) -> Execute { proc(
    args: ["merge"]
    + message.map { ["-m", $0] }.get(["--no-commit"])
    + noFf.then(["--no-ff"]).get([])
    + refs.map(\.value),
    env: env,
    escalate: escalate
  )}
  var quitMerge: Execute { proc(
    args: ["merge", "--quit"]
  )}
  var addAll: Execute { proc(
    args: ["add", "--all"]
  )}
  func resetHard(ref: Ref) -> Execute { proc(
    args: ["reset", "--hard", ref.value]
  )}
  func resetSoft(ref: Ref) -> Execute { proc(
    args: ["reset", "--soft", ref.value]
  )}
  func commit(message: String) -> Execute { proc(
    args: ["commit", "-m", message]
  )}
  var listTags: Execute { proc(
    args: ["ls-remote", "--tags", "--refs"]
  )}
  static func resolveTopLevel(
    path: Files.Absolute
  ) -> Execute { .init(tasks: [.init(
    environment: [:],
    arguments: ["git", "-C", path.value, "rev-parse", "--show-toplevel"]
  )])}
  static func env(
    authorName: String? = nil,
    authorEmail: String? = nil,
    authorDate: String? = nil,
    commiterName: String? = nil,
    commiterEmail: String? = nil,
    commiterDate: String? = nil
  ) -> [String: String] {
    var result: [String: String] = [:]
    result["GIT_AUTHOR_NAME"] = authorName
    result["GIT_AUTHOR_EMAIL"] = authorEmail
    result["GIT_AUTHOR_DATE"] = authorDate
    result["GIT_COMMITTER_NAME"] = commiterName
    result["GIT_COMMITTER_EMAIL"] = commiterEmail
    result["GIT_COMMITTER_DATE"] = commiterDate
    return result
  }
}
extension Git {
  func proc(
    args: [String],
    env: [String: String] = [:],
    escalate: Bool = true
  ) -> Execute { .init(tasks: [.init(
    escalate: escalate,
    environment: self.env
      .merging(env, uniquingKeysWith: { $1 }),
    arguments: ["git", "-C", root.value]
    + ["-c", "core.quotepath=false", "-c", "core.precomposeunicode=true"]
    + args
  )])}
}
