import Foundation
import Facility
import FacilityPure
import FacilityFair
import InteractivityCommon
import InteractivityYams
import InteractivityStencil
import InteractivityPathKit
enum Context {
  final class Shell: ContextLocal {
    public let sh: Ctx.Sh
    public let repo: Ctx.Repo
    init(profile: String) throws {
      self.sh = Ctx.Sh.make(
        env: ProcessInfo.processInfo.environment,
        stdin: FileHandle.standardInput.readToEnd,
        stdout: FileHandle.standardOutput.write(_:),
        stderr: FileHandle.standardError.write(_:),
        unyaml: YamlParser.decodeYaml(content:),
        execute: Processor.execute(query:),
        dialect: .json
      )
      let file = try Finder.resolve(query: .make(path: profile))
      var git = try Ctx.Git.make(root: sh.gitTopLevel(path: Finder.parent(path: file)))
      try sh.updateLfs(git: &git)
      let sha = try sh.getSha(git: git, ref: .head)
      let profile = try Profile.make(
        location: .make(ref: sha.ref, path: file.relative(to: git.root)),
        yaml: sh.dialect.read(
          Yaml.Profile.self,
          from: sh.unyaml(String.make(utf8: FileLiner.read(file: file)))
        )
      )
      self.repo = try .make(
        git: git,
        sha: sha,
        branch: sh.getCurrentBranch(git: git),
        profile: profile,
        generate: StencilParser(notation: .json, sh: sh, git: git, profile: profile)
          .generate(query:)
      )
    }
  }
}
//  public let root: Files.Absolute
//  public let lfs: Bool = false
//  public let sha: Git.Sha
//  public let branch: Git.Branch?
//  public let profile: Yaml.Profile
//  public let generate: Try.Reply<Generate>
//  public let decodeYaml: Try.Of<String>.Do<AnyCodable>
//  public var env: [String: String] { ProcessInfo.processInfo.environment }
//  public var execute: Try.Reply<Execute> { Processor.execute(query:) }
//  let stencil: Lossy<StencilParser>
//  public init(
//    profile: String
//    writeStdout: @escaping Act.Of<Data>.Go,
//    writeStderr: @escaping Act.Of<Data>.Go,
//    readStdin: @escaping Try.Do<Data?>,
//    decodeYaml: @escaping Try.Of<String>.Do<AnyCodable>,
//    execute: @escaping Try.Reply<Execute>,
//    env: [String: String],
//  ) throws {
//    var profile = try Finder.resolveFile(path: profile)
//    var repo = try Finder.resolveFileDirectory(path: profile)
//    self.root = try Execute. execute(Git.resolveTopLevel(path: repo)).text.get()
//    profile = try profile.dropPrefix("\(repo)/")
//    root =
//    var git = Git(env: env, root: .init(value: repo))
//    git.lfs = try execute(git.updateLfs).success
//    self.git = git
//    self.sha = execute(git.getSha(ref: .head)).text.
//
//    var git = try Id(repoPath)
//      .map(Files.Absolute.init(value:))
//      .map(Git.resolveTopLevel(path:))
//      .map(execute)
//      .map(Execute.parseText(reply:))
//      .map(Files.Absolute.init(value:))
//      .reduce(env, Git.init(env:root:))
//      .get()
//    git.lfs = try Id(git.updateLfs)
//      .map(execute)
//      .map(Execute.parseSuccess(reply:))
//      .get()
//      let profilePath = try Id(profile)
//        .map(Files.ResolveAbsolute.make(path:))
//        .map(resolveAbsolute)
//        .get()
//      let repoPath = profilePath.value
//        .components(separatedBy: "/")
//        .dropLast()
//        .joined(separator: "/")
//      var git = try Id(repoPath)
//        .map(Files.Absolute.init(value:))
//        .map(Git.resolveTopLevel(path:))
//        .map(execute)
//        .map(Execute.parseText(reply:))
//        .map(Files.Absolute.init(value:))
//        .reduce(env, Git.init(env:root:))
//        .get()
//      git.lfs = try Id(git.updateLfs)
//        .map(execute)
//        .map(Execute.parseSuccess(reply:))
//        .get()
//      let profile = try Git.File(
//        ref: .head,
//        path: .init(value: profilePath.value.dropPrefix("\(git.root.value)/"))
//      )
//      var cfg = try Id(profile)
//        .reduce(git, parse(git:yaml:))
//        .reduce(Yaml.Profile.self, dialect.read(_:from:))
//        .reduce(profile, Configuration.Profile.make(location:yaml:))
//        .map({ Configuration.make(git: git, env: env, profile: $0) })
//        .get()
//
//    self.execute = execute
//    self.writeStdout = writeStdout
//    self.writeStderr = writeStderr
//    self.readStdin = readStdin
//  }
//}
//
//
//static let stencilParser = StencilParser(notation: .json)
//static let jsonDecoder: JSONDecoder = {
//  let result = JSONDecoder()
//  result.keyDecodingStrategy = .convertFromSnakeCase
//  return result
//}()
//static let writeStdout = FileHandle.standardOutput.write(message:)
//static let stdoutData = FileHandle.standardOutput.write(data:)
//static let writeStderr = FileHandle.standardError.write(message:)
//static let readStdin = FileHandle.readStdin
//static let execute = Processor.execute(query:)
