import Foundation
import Facility
import FacilityPure
import FacilityFair
import InteractivityCommon
import InteractivityYams
import InteractivityStencil
import InteractivityPathKit
final class Shell: ContextLocal {
  public let sh: Ctx.Sh
  public let repo: Ctx.Repo
  init(profile: String, version: String) throws {
    self.sh = Ctx.Sh.make(
      env: ProcessInfo.processInfo.environment,
      stdin: FileHandle.standardInput.readToEnd,
      stdout: FileHandle.standardOutput.write(_:),
      stderr: FileHandle.standardError.write(_:),
      read: FileLiner.read(file:),
      unyaml: YamlParser.decodeYaml(content:),
      execute: Processor.execute(query:),
      resolveAbsolute: Finder.resolve(query:),
      dialect: .json
    )
    let file = try sh.resolveAbsolute(.make(path: profile))
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
    guard version == profile.version
    else { throw Thrown("Profile version(\(version)) mismatch executable(\(profile.version))") }
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
extension ContractPayload {
  func supportGitlabReview(ctx: Shell) throws {
    let sender = try GitlabSender(ctx: ctx)
    guard case .value = sender.gitlab.current.review else { throw Thrown("Not review job") }
    try sender.triggerPipeline(variables: encode(
      job: sender.gitlab.current.id, version: ctx.repo.profile.version
    ))
  }
  func supportGitlabProtected(ctx: Shell) throws {
    let sender = try GitlabSender(ctx: ctx)
    let protected = try sender.gitlab.protected.get()
    try sender.createPipeline(protected: protected, variables: encode(
      job: sender.gitlab.current.id, version: ctx.repo.profile.version
    ))
  }
  func supportGitlab(ctx: Shell) throws {
    let sender = try GitlabSender(ctx: ctx)
    let variables = try encode(job: sender.gitlab.current.id, version: ctx.repo.profile.version)
    if let protected = try? sender.gitlab.protected.get() {
      try sender.createPipeline(protected: protected, variables: variables)
    } else if case .value = sender.gitlab.current.review {
      try sender.triggerPipeline(variables: variables)
    } else {
      throw Thrown("Not either review or protected ref job")
    }
  }
}
