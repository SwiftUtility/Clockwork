import Foundation
import Facility
public enum Ctx {
  public struct Sh {
    public let env: [String: String]
    public let stdin: Try.Do<Data?>
    public let stdout: Act.Of<Data>.Go
    public let stderr: Act.Of<Data>.Go
    public let read: Try.Of<Sys.Absolute>.Do<Data>
    public let lineIterator: Try.Of<Sys.Absolute>.Do<AnyIterator<String>>
    public let listDirectories: Try.Of<Sys.Absolute>.Do<[String]>
    public let unyaml: Try.Of<String>.Do<AnyCodable>
    public let execute: Try.Reply<Execute>
    public let resolveAbsolute: Try.Reply<Ctx.Sys.Absolute.Resolve>
    public let getTime: Act.Do<Date>
    public let dialect: AnyCodable.Dialect
    public let formatter: DateFormatter
    public let rawEncoder: JSONEncoder
    public let rawDecoder: JSONDecoder
    public let plistDecoder: PropertyListDecoder
    public static func make(
      env: [String : String],
      stdin: @escaping Try.Do<Data?>,
      stdout: @escaping Act.Of<Data>.Go,
      stderr: @escaping Act.Of<Data>.Go,
      read: @escaping Try.Of<Sys.Absolute>.Do<Data>,
      lineIterator: @escaping Try.Of<Sys.Absolute>.Do<AnyIterator<String>>,
      listDirectories: @escaping Try.Of<Sys.Absolute>.Do<[String]>,
      unyaml: @escaping Try.Of<String>.Do<AnyCodable>,
      execute: @escaping Try.Reply<Execute>,
      resolveAbsolute: @escaping Try.Reply<Ctx.Sys.Absolute.Resolve>,
      getTime: @escaping Act.Do<Date>
    ) -> Self { .init(
      env: env,
      stdin: stdin,
      stdout: stdout,
      stderr: stderr,
      read: read,
      lineIterator: lineIterator,
      listDirectories: listDirectories,
      unyaml: unyaml,
      execute: execute,
      resolveAbsolute: resolveAbsolute,
      getTime: getTime,
      dialect: .json,
      formatter: {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
      }(),
      rawEncoder: .init(),
      rawDecoder: .init(),
      plistDecoder: .init()
    )}
  }
  public struct Repo {
    public let git: Git
    public let sha: Git.Sha
    public let branch: Git.Branch?
    public let profile: Profile
    public static func make(
      git: Git, sha: Git.Sha,
      branch: Git.Branch?,
      profile: Profile
    ) -> Self { .init(
      git: git, sha: sha, branch: branch, profile: profile
    )}
  }
  public enum Sys {
    public struct Relative: Hashable {
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
      public static var head: Self { .init(value: "HEAD") }
      public static func make(sha: String) throws -> Self {
        return try Sha.make(value: sha).ref
      }
      public static func make(tag: String) throws -> Self {
        return try Tag.make(name: tag).ref
      }
      public static func make(local branch: String) throws -> Self {
        return try Branch.make(name: branch).local
      }
      public static func make(remote branch: String) throws -> Self {
        return try Branch.make(name: branch).remote
      }
      public func make(parent number: Int) throws -> Self {
        guard number > 0 else { throw MayDay("commit parent must be > 0") }
        return .init(value: "\(value)^\(number)")
      }
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
  public enum Secret {
    case value(String)
    case envVar(String)
    case envFile(String)
    case sysFile(String)
    case gitFile(Git.File)
    public static func make(yaml: Yaml.Secret) throws -> Self {
      switch (yaml.value, yaml.envVar, yaml.envFile, yaml.sysFile, yaml.gitFile) {
      case (let value?, nil, nil, nil, nil): return .value(value)
      case (nil, let envVar?, nil, nil, nil): return .envVar(envVar)
      case (nil, nil, let envFile?, nil, nil): return .envFile(envFile)
      case (nil, nil, nil, let sysFile?, nil): return .sysFile(sysFile)
      case (nil, nil, nil, nil, let gitFile?): return try .gitFile(.init(
        ref: Git.Branch.make(name: gitFile.branch).remote,
        path: .init(value: gitFile.path)
      ))
      default: throw Thrown("Wrong secret format")
      }
    }
  }
  public enum Template {
    case name(String)
    case value(String)
    public var name: String {
      switch self {
      case .value(let value): return String(value.prefix(30))
      case .name(let name): return name
      }
    }
    public static func make(yaml: Yaml.Template) throws -> Self {
      guard [yaml.name, yaml.value].compactMap({$0}).count < 2
      else { throw Thrown("Multiple values in template") }
      if let value = yaml.name { return .name(value) }
      else if let value = yaml.value { return .value(value) }
      else { throw Thrown("No values in template") }
    }
  }
  public struct Gitlab {
    public let cfg: Cfg
    public let api: String
    public let token: String
    public let protected: Lossy<Protected>
    public let current: Json.GitlabJob
    public let apiEncoder: JSONEncoder
    public let apiDecoder: JSONDecoder
    public static func make(
      cfg: Cfg,
      api: String,
      token: String,
      protected: Lossy<Protected>,
      current: Json.GitlabJob,
      apiEncoder: JSONEncoder,
      apiDecoder: JSONDecoder
    ) -> Self {
      return .init(
        cfg: cfg,
        api: api,
        token: token,
        protected: protected,
        current: current,
        apiEncoder: apiEncoder,
        apiDecoder: apiDecoder
      )
    }
    public struct Cfg {
      public var contract: Git.Tag
      public var apiToken: Secret
      public var storage: Sys.Relative
      public var review: Template?
      public var notes: [String: Note]?
      public static func make(yaml: Yaml.Gitlab) throws -> Self { try .init(
        contract: .make(name: yaml.contract),
        apiToken: .make(yaml: yaml.apiToken),
        storage: .make(value: yaml.storage.path),
        review: yaml.review.map(Template.make(yaml:)),
        notes: yaml.notes.get([:]).map(Note.make(mark:yaml:)).indexed(\.mark)
      )}
      public struct Note {
        public var mark: String
        public var text: Configuration.Template
        public var events: [[String]]
        public static func make(mark: String, yaml: Yaml.Gitlab.Note) throws -> Self { try .init(
          mark: mark,
          text: .make(yaml: yaml.text),
          events: yaml.events.map({ $0.components(separatedBy: "/") })
        )}
      }
    }
    public struct Protected {
      public let rest: String
      public let proj: Json.GitlabProject
      public static func make(
        rest: String,
        proj: Json.GitlabProject
      ) -> Self { .init(
        rest: rest,
        proj: proj
      )}
    }
    public struct Contracted {
      public let sender: Sender
      public let user: Json.GitlabUser
      public let parent: Json.GitlabJob
      public let contract: Contract
      public static func make(
        sender: Sender,
        user: Json.GitlabUser,
        parent: Json.GitlabJob,
        contract: Contract
      ) -> Self { .init(
        sender: sender,
        user: user,
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
public protocol ContextGitlabContracted: ContextGitlab {
  var protected: Ctx.Gitlab.Protected { get }
  var contracted: Ctx.Gitlab.Contracted { get }
}
