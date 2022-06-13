import Foundation
import Facility
import FacilityAutomates
public extension Git {
  func listChangedFiles(source: Ref, target: Ref) -> HandleFileList {
    .init(tasks: [.init(arguments: root.base + [
      "diff", "--name-only", "--merge-base", target.value, source.value
    ])])
  }
  var listConflictMarkers: HandleLine {
    .init(tasks: [.init(arguments: root.base + [
      "-c",
      "core.whitespace=" + [
        "-trailing-space",
        "-space-before-tab",
        "-indent-with-non-tab",
        "-tab-in-indent",
        "-cr-at-eol",
      ].joined(separator: ","),
      "diff",
      "--check",
      "HEAD"
    ])])
  }
  var listLocalChanges: HandleFileList {
    .init(tasks: [.init(arguments: root.base + ["diff", "--name-only", "HEAD"])])
  }
  var listLocalRefs: HandleLine {
    .init(tasks: [.init(arguments: root.base + ["diff", "show-ref", "--head"])])
  }
  func check(child: Ref, parent: Ref) -> HandleVoid {
    .init(tasks: [.init(arguments: root.base + [
      "merge-base", "--is-ancestor", parent.value, child.value
    ])])
  }
  func detach(to ref: Ref) -> HandleVoid {
    .init(tasks: [.init(arguments: root.base + ["checkout", "--force", "--detach", ref.value])])
  }
  func listChangedOutsideFiles(source: Ref, target: Ref) -> HandleFileList {
    .init(tasks: [.init(arguments: root.base + [
      "diff", "--name-only", "\(source.value)...\(target.value)"
    ])])
  }
  func listAllTrackedFiles(ref: Ref) -> HandleFileList {
    .init(tasks: [.init(arguments: root.base + [
      "ls-tree", "-r", "--name-only", "--full-tree", ref.value, "."
    ])])
  }
  func listTreeTrackedFiles(dir: Dir) -> HandleFileList {
    .init(tasks: [.init(arguments: root.base + [
      "ls-tree", "-r", "--name-only", "--full-tree", dir.ref.value, dir.path.value
    ])])
  }
  func checkRefType(ref: Ref) -> HandleLine {
    .init(tasks: [.init(arguments: root.base + ["cat-file", "-t", ref.value])])
  }
  func make(listCommits: HandleLine.ListCommits) -> HandleLine {
    .init(tasks: [.init(arguments: root.base + listCommits.arguments)])
  }
  var writeTree: HandleLine {
    .init(tasks: [.init(arguments: root.base + ["write-tree"])])
  }
  func make(commitTree: HandleLine.CommitTree) -> HandleLine {
    .init(tasks: [.init(
      environment: commitTree.env,
      arguments: root.base + commitTree.arguments
    )])
  }
  func getAuthorName(ref: Ref) -> HandleLine {
    .init(tasks: [.init(arguments: root.base + ["show", "-s", "--format=%aN", ref.value])])
  }
  func getAuthorEmail(ref: Ref) -> HandleLine {
    .init(tasks: [.init(arguments: root.base + ["show", "-s", "--format=%aE", ref.value])])
  }
  func getAuthorDate(ref: Ref) -> HandleLine {
    .init(tasks: [.init(arguments: root.base + ["show", "-s", "--format=%ad", ref.value])])
  }
  func getCommiterName(ref: Ref) -> HandleLine {
    .init(tasks: [.init(arguments: root.base + ["show", "-s", "--format=%cN", ref.value])])
  }
  func getCommiterEmail(ref: Ref) -> HandleLine {
    .init(tasks: [.init(arguments: root.base + ["show", "-s", "--format=%cE", ref.value])])
  }
  func getCommiterDate(ref: Ref) -> HandleLine {
    .init(tasks: [.init(arguments: root.base + ["show", "-s", "--format=%cd", ref.value])])
  }
  func getCommitMessage(ref: Ref) -> HandleLine {
    .init(tasks: [.init(arguments: root.base + ["show", "-s", "--format=%B", ref.value])])
  }
  func listParents(ref: Ref) -> HandleLine {
    .init(tasks: [.init(arguments: root.base + ["rev-parse", "\(ref.value)^@"])])
  }
  func mergeBase(_ one: Ref, _ two: Ref) -> HandleLine {
    .init(tasks: [.init(arguments: root.base + [
      "merge-base", one.value, two.value
    ])])
  }
  func make(push: HandleVoid.Push) -> HandleVoid {
    .init(tasks: [.init(arguments: root.base + push.arguments)])
  }
  func push(remote: String, delete branch: Branch) -> HandleVoid {
    .init(tasks: [.init(arguments: root.base + ["push", remote, ":\(Ref.make(local: branch))"])])
  }
  var updateLfs: HandleVoid {
    .init(tasks: [.init(arguments: root.base + ["lfs", "update"])])
  }
  var fetch: HandleVoid { .init(tasks: [.init(arguments: root.base + [
    "fetch",
    "origin",
    "--prune",
    "--prune-tags",
    "--tags",
  ])])}
  func cat(file: File) throws -> HandleCat {
    var tasks: [PipeTask] = [
      .init(arguments: root.base + ["show", "\(file.ref.value):\(file.path.value)"]),
    ]
    tasks += lfs
      .then(.init(surpassStdErr: true, arguments: root.base + ["lfs", "smudge"]))
      .makeArray()
    return .init(tasks: tasks)
  }
  var userName: HandleLine {
    .init(tasks: [.init(arguments: root.base + ["config", "user.name"])])
  }
  func getSha(ref: Ref) -> HandleLine {
    .init(tasks: [.init(arguments: root.base + ["rev-parse", ref.value])])
  }
  func create(branch: Branch, at sha: Sha) -> HandleVoid {
    .init(tasks: [.init(arguments: root.base + ["checkout", "-B", branch.name, sha.value])])
  }
  var clean: HandleVoid {
    .init(tasks: [.init(arguments: root.base + ["clean", "-fdx"])])
  }
  func make(merge: HandleVoid.Merge) -> HandleVoid {
    .init(tasks: [.init(
      environment: merge.env,
      arguments: root.base + merge.arguments
    )])
  }
  var quitMerge: HandleVoid {
    .init(tasks: [.init(arguments: root.base + ["merge", "--quit"])])
  }
  var addAll: HandleVoid {
    .init(tasks: [.init(arguments: root.base + ["add", "--all"])])
  }
  func resetHard(ref: Ref) -> HandleVoid {
    .init(tasks: [.init(arguments: root.base + ["reset", "--hard", ref.value])])
  }
  func resetSoft(ref: Ref) -> HandleVoid {
    .init(tasks: [.init(arguments: root.base + ["reset", "--soft", ref.value])])
  }
  func commit(message: String) -> HandleVoid {
    .init(tasks: [.init(arguments: root.base + ["commit", "-m", message])])
  }
  var listTags: HandleLine {
    .init(tasks: [.init(arguments: root.base + ["ls-remote", "--tags", "--refs"])])
  }
  static func makeEnvironment(
    authorName: String? = nil,
    authorEmail: String? = nil,
    authorDate: String? = nil,
    commiterName: String? = nil,
    commiterEmail: String? = nil,
    commiterDate: String? = nil,
    base: [String: String] = [:]
  ) -> [String: String] {
    var result = base
    result["GIT_AUTHOR_NAME"] = authorName
    result["GIT_AUTHOR_EMAIL"] = authorEmail
    result["GIT_AUTHOR_DATE"] = authorDate
    result["GIT_COMMITTER_NAME"] = commiterName
    result["GIT_COMMITTER_EMAIL"] = commiterEmail
    result["GIT_COMMITTER_DATE"] = commiterDate
    return result
  }
  struct HandleFileList: ProcessHandler {
    public var tasks: [PipeTask]
    public func handle(data: Data) throws -> Reply { try Id
      .make(data)
      .map(String.make(utf8:))
      .reduce(tryCurry: .newlines, String.components(separatedBy:))
      .get()
      .map { $0.trimmingCharacters(in: .init(charactersIn: "\"")) }
      .filter { !$0.isEmpty }
    }
    public typealias Reply = [String]
  }
  struct HandleLine: ProcessHandler {
    public var tasks: [PipeTask]
    public func handle(data: Data) throws -> Reply { try Id
      .make(data)
      .map(String.make(utf8:))
      .reduce(curry: .newlines, String.trimmingCharacters(in:))
      .get()
    }
    public static func make(resolveTopLevel path: Path.Absolute) -> Self {
      .init(tasks: [.init(arguments: path.base + ["rev-parse", "--show-toplevel"])])
    }
    public typealias Reply = String
    public struct ListCommits {
      public var include: [Ref]
      public var exclude: [Ref]
      public var noMerges: Bool
      public var firstParents: Bool
      public init(
        include: [Ref],
        exclude: [Ref],
        noMerges: Bool,
        firstParents: Bool
      ) {
        self.include = include
        self.exclude = exclude
        self.noMerges = noMerges
        self.firstParents = firstParents
      }
      public var arguments: [String] {
        ["log", "--format=%H"]
        + firstParents.then(["--first-parent"]).or([])
        + noMerges.then(["--no-merges"]).or([])
        + include.map(\.value)
        + exclude.map { "^\($0.value)" }
      }
    }
    public struct CommitTree {
      public var tree: Tree
      public var message: String
      public var parents: [Ref]
      public var env: [String: String]
      public init(
        tree: Tree,
        message: String,
        parents: [Ref],
        env: [String: String]
      ) {
        self.tree = tree
        self.message = message
        self.parents = parents
        self.env = env
      }
      public var arguments: [String] {
        ["commit-tree", tree.value, "-m", message]
        + parents.flatMap { ["-p", $0.value] }
      }
    }
  }
  struct HandleVoid: ProcessHandler {
    public var tasks: [PipeTask]
    public func handle(data: Data) throws -> Reply {}
    public typealias Reply = Void
    public struct Push {
      public var url: String
      public var branch: Branch
      public var sha: Sha
      public var force: Bool
      public init(url: String, branch: Branch, sha: Sha, force: Bool) {
        self.url = url
        self.branch = branch
        self.sha = sha
        self.force = force
      }
      public var arguments: [String] {
        ["push", url]
        + force.then(["--force"]).or([])
        + ["\(sha.value):\(Ref.make(local: branch).value)"]
      }
    }
    public struct Merge {
      public var ref: Ref
      public var message: String?
      public var noFf: Bool
      public var env: [String: String]
      public init(
        ref: Ref,
        message: String?,
        noFf: Bool,
        env: [String: String] = [:]
      ) {
        self.ref = ref
        self.message = message
        self.noFf = noFf
        self.env = env
      }
      public var arguments: [String] {
        ["merge"]
        + message.map { ["-m", $0] }.or(["--no-commit"])
        + noFf.then(["--no-ff"]).or([])
        + [ref.value]
      }
    }
  }
  struct HandleCat: ProcessHandler {
    public var tasks: [PipeTask]
    public func handle(data: Data) throws -> Reply { data }
    public typealias Reply = Data
  }
}
private extension Path.Absolute {
  var base: [String] { ["git", "-C", value] }
}
