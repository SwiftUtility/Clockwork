import Foundation
import Facility
public enum Ctx {
  public struct Sh {
    public let env: [String: String]
    public let stdin: Try.Do<Data?>
    public let stdout: Act.Of<Data>.Go
    public let stderr: Act.Of<Data>.Go
    public let unyaml: Try.Of<String>.Do<AnyCodable>
    public let execute: Try.Reply<Execute>
    public let dialect: AnyCodable.Dialect
    public static func make(
      env: [String : String],
      stdin: @escaping Try.Do<Data?>,
      stdout: @escaping Act.Of<Data>.Go,
      stderr: @escaping Act.Of<Data>.Go,
      unyaml: @escaping Try.Of<String>.Do<AnyCodable>,
      execute: @escaping Try.Reply<Execute>,
      dialect: AnyCodable.Dialect
    ) -> Self { .init(
      env: env,
      stdin: stdin,
      stdout: stdout,
      stderr: stderr,
      unyaml: unyaml,
      execute: execute,
      dialect: dialect
    )}
  }
  public struct Repo {
    public let git: Git
    public let sha: Git.Sha
    public let branch: Git.Branch?
    public let profile: Profile
    public let generate: Try.Reply<Generate>
    public static func make(
      git: Git, sha: Git.Sha,
      branch: Git.Branch?,
      profile: Profile,
      generate: @escaping Try.Reply<Generate>
    ) -> Self { .init(
      git: git, sha: sha, branch: branch, profile: profile, generate: generate
    )}
  }
  public enum Sys {
    public struct Relative {
      public var value: String
      public static func make(value: String) throws -> Self {
        guard value.starts(with: "/").not else { throw Thrown("Not relative path \(value)") }
        return .init(value: value)
      }
    }
    public struct Absolute {
      public var value: String
      public func resolve(path: String) -> Resolve {
        .init(path: path, relativeTo: self)
      }
      public func relative(to path: Self) throws -> Relative {
        try .init(value: value.dropPrefix("\(path.value)/"))
      }
      public static func make(value: String) throws -> Self {
        guard value.isEmpty.not else { throw Thrown("Empty absolute path") }
        guard value.starts(with: "/") else { throw Thrown("Not absolute path \(value)") }
        return .init(value: value)
      }
      public struct Resolve: Query {
        public var path: String
        public var relativeTo: Absolute?
        public static func make(path: String) -> Self { .init(path: path, relativeTo: nil) }
        public typealias Reply = Absolute
      }
    }
  }
  public struct Git {
    public var root: Sys.Absolute
    public var lfs: Bool = false
    public static func make(root: Sys.Absolute) throws -> Self { .init(root: root) }
    public struct File {
      public var ref: Ref
      public var path: Sys.Relative
      public static func make(ref: Ref, path: Sys.Relative) -> Self { .init(
        ref: ref, path: path
      )}
    }
    public struct Dir {
      public var ref: Ref
      public var path: Sys.Relative
      public static func make(ref: Ref, path: Sys.Relative) -> Self { .init(
        ref: ref, path: path
      )}
    }
    public struct Ref {
      public var value: String
      public var tree: Tree { .init(value: "\(value)^{tree}") }
      public func make(parent number: Int) throws -> Self {
        guard number > 0 else { throw MayDay("commit parent must be > 0") }
        return .init(value: "\(value)^\(number)")
      }
      public static var head: Self { .init(value: "HEAD") }
    }
    public struct Sha: Hashable, Comparable {
      public var value: String
      public var ref: Ref { .init(value: value) }
      public static func make(value: String) throws -> Self {
        guard value.count == 40, value.trimmingCharacters(in: .hexadecimalDigits).isEmpty
        else { throw Thrown("Not sha: \(value)") }
        return .init(value: value)
      }
      public static func make(job: Json.GitlabJob) throws -> Self {
        return try .make(value: job.pipeline.sha)
      }
      public static func make(merge: Json.GitlabMergeState) throws -> Self {
        return try .make(value: merge.lastPipeline.sha)
      }
      public static func < (lhs: Git.Sha, rhs: Git.Sha) -> Bool { lhs.value < rhs.value }
    }
    public struct Tree {
      public var value: String
    }
    public struct Branch: Hashable, Comparable {
      public var name: String
      public var local: Ref { .init(value: "refs/heads/\(name)") }
      public var remote: Ref { .init(value: "refs/remotes/origin/\(name)") }
      public static func make(name: String) throws -> Self {
        guard !name.isEmpty, !name.hasPrefix("/"), !name.hasSuffix("/"), !name.contains(" ")
        else { throw Thrown("invalid branch name \(name)") }
        return .init(name: name)
      }
      public static func make(job: Json.GitlabJob) throws -> Self {
        guard job.tag.not else { throw Thrown("Not branch job \(job.webUrl)") }
        return try .make(name: job.pipeline.ref)
      }
      public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.name.compare(rhs.name, options: .numeric) == .orderedAscending
      }
    }
    public struct Tag: Hashable, Comparable {
      public var name: String
      public var ref: Ref { .init(value: "refs/tags/\(name)") }
      private init(name: String) { self.name = name }
      public static func make(name: String) throws -> Self {
        guard !name.isEmpty, !name.hasPrefix("/"), !name.hasSuffix("/"), !name.contains(" ")
        else { throw Thrown("invalid tag name \(name)") }
        return .init(name: name)
      }
      public static func make(job: Json.GitlabJob) throws -> Self {
        guard job.tag else { throw Thrown("Not tag job \(job.webUrl)") }
        return try .make(name: job.pipeline.ref)
      }
      public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.name.compare(rhs.name, options: .numeric) == .orderedAscending
      }
    }
  }
  public struct Gitlab {
    public let api: String
    public let token: String
    public let current: Json.GitlabJob
    public static func make(
      api: String,
      token: String,
      current: Json.GitlabJob
    ) -> Self { .init(
      api: api,
      token: token,
      current: current
    )}
    public struct Protected {
      public let rest: String
      public let user: Json.GitlabUser
      public let proj: Json.GitlabProject
    }
    public struct Contracted {
      public let sender: Sender
      public let parent: Json.GitlabJob
      public let contract: Contract
      public static func make(
        sender: Sender,
        parent: Json.GitlabJob,
        contract: Contract
      ) -> Self { .init(
        sender: sender,
        parent: parent,
        contract: contract
      )}
      public enum Sender {
        case tag(Json.GitlabTag)
        case merge(Json.GitlabMergeState)
        case branch(Json.GitlabBranch)
      }
    }
  }
}
public protocol ContextLocal {
  var sh: Ctx.Sh { get }
  var repo: Ctx.Repo { get }
}
public protocol ContextGitlab: ContextLocal {
  var gitlab: Ctx.Gitlab { get }
}
public protocol ContextGitlabReview: ContextGitlab {
  var review: UInt { get }
}
public protocol ContextGitlabProtected: ContextGitlab {
  var protected: Ctx.Gitlab.Protected { get }
}
public protocol ContextGitlabContracted: ContextGitlabProtected {
  var contracted: Ctx.Gitlab.Contracted { get }
}
