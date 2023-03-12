import Foundation
import Facility
import FacilityPure
import FacilityFair
import InteractivityCommon
import InteractivityYams
import InteractivityStencil
import InteractivityPathKit
final class Repo: ContextRepo {
  let sh: Ctx.Sh
  let git: Ctx.Git
  let repo: Ctx.Repo
  init(profile: String) throws {
    self.sh = .make(
      env: ProcessInfo.processInfo.environment,
      stdin: FileHandle.standardInput.readToEnd,
      stdout: FileHandle.standardOutput.write(_:),
      stderr: FileHandle.standardError.write(_:),
      read: FileHandle.read(file:),
      lineIterator: FileHandle.lineIterator(file:),
      listDirectories: Finder.listDirectories(path:),
      unyaml: YamlParser.decodeYaml(content:),
      execute: Processor.execute(query:),
      resolveAbsolute: Finder.resolve(query:),
      getTime: Date.init
    )
    let file = try sh.resolveAbsolute(.make(path: profile))
    self.git = try Ctx.Git.make(sh: sh, dir: Finder.parent(path: file))
    let sha = try git.getSha(sh: sh, ref: .head)
    let profile = try Profile.make(
      location: .make(ref: sha.ref, path: file.relative(to: git.root)),
      yaml: sh.dialect.read(
        Yaml.Profile.self,
        from: sh.unyaml(String.make(utf8: FileHandle.read(file: file)))
      )
    )
    let version = Clockwork.version
    guard version == profile.version
    else { throw Thrown("Profile version(\(version)) mismatch executable(\(profile.version))") }
    self.repo = try .make(
      sha: sha,
      branch: git.getCurrentBranch(sh: sh),
      profile: profile
    )
  }
  var generate: Try.Of<Generate>.Do<String> {
    StencilParser(ctx: self).generate(query:)
  }
  func gitlab() throws -> ContextGitlab {
    try GitlabSender(ctx: self)
  }
  func exclusive() throws -> ContextExclusive {
    try GitlabExecutor(sender: .init(ctx: self), generate: generate)
  }
  func parse(_ parse: Common.Parse) throws -> AnyCodable? {
    switch parse.stdin {
    case .ignore: return nil
    case .lines:
      let stdin = try sh.stdin()
        .map(String.make(utf8:))?
        .trimmingCharacters(in: .newlines)
        .components(separatedBy: .newlines)
      return try stdin.map(AnyCodable.init(any:))
    case .json: return try sh.stdin().reduce(AnyCodable.self, sh.rawDecoder.decode(_:from:))
    case .yaml: return try sh.stdin()
      .map(String.make(utf8:))
      .map(sh.unyaml)
    }
  }
  static func handle(profile: String, handler: Try.Of<Repo>.Do<Performer>) throws -> Bool {
    let repo = try Repo(profile: profile)
    return try handler(repo).perform(repo: repo)
  }
}
private extension Contract {
  
}
