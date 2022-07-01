import Foundation
import Facility
import FacilityPure
public final class Producer {
  let execute: Try.Reply<Execute>
  let generate: Try.Reply<Generate>
  let writeFile: Try.Reply<Files.WriteFile>
  let resolveProduction: Try.Reply<Configuration.ResolveProduction>
  let resolveProductionVersions: Try.Reply<Configuration.ResolveProductionVersions>
  let resolveProductionBuilds: Try.Reply<Configuration.ResolveProductionBuilds>
  let persistBuilds: Try.Reply<Configuration.PersistBuilds>
  let persistVersions: Try.Reply<Configuration.PersistVersions>
  let report: Act.Reply<Report>
  let logMessage: Act.Reply<LogMessage>
  let writeStdout: Act.Of<String>.Go
  let worker: Worker
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    generate: @escaping Try.Reply<Generate>,
    writeFile: @escaping Try.Reply<Files.WriteFile>,
    resolveProduction: @escaping Try.Reply<Configuration.ResolveProduction>,
    resolveProductionVersions: @escaping Try.Reply<Configuration.ResolveProductionVersions>,
    resolveProductionBuilds: @escaping Try.Reply<Configuration.ResolveProductionBuilds>,
    persistBuilds: @escaping Try.Reply<Configuration.PersistBuilds>,
    persistVersions: @escaping Try.Reply<Configuration.PersistVersions>,
    report: @escaping Act.Reply<Report>,
    logMessage: @escaping Act.Reply<LogMessage>,
    writeStdout: @escaping Act.Of<String>.Go,
    worker: Worker,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.generate = generate
    self.writeFile = writeFile
    self.resolveProduction = resolveProduction
    self.resolveProductionVersions = resolveProductionVersions
    self.resolveProductionBuilds = resolveProductionBuilds
    self.persistBuilds = persistBuilds
    self.persistVersions = persistVersions
    self.report = report
    self.logMessage = logMessage
    self.writeStdout = writeStdout
    self.worker = worker
    self.jsonDecoder = jsonDecoder
  }
  public func createDeployTag(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    guard !gitlabCi.job.tag else { throw Thrown("Not on branch") }
    let product = try production
      .productMatching(ref: gitlabCi.job.pipeline.ref, tag: false)
      .get { throw Thrown("No product matches \(gitlabCi.job.pipeline.ref)") }
    try gitlabCi.job.checkPermission(users: product.mainatiners)
    let version = try generate(cfg.parseReleaseBranchVersion(
      product: product,
      ref: gitlabCi.job.pipeline.ref
    ))
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    let head = try Git.Sha(value: gitlabCi.job.pipeline.sha)
    var uniq: Set<Git.Sha>? = nil
    var heir: Set<Git.Sha>? = nil
    var lack: Set<Git.Sha> = []
    for build in builds.reversed() {
      guard case .deploy(let deploy) = build, deploy.product == product.name else { continue }
      let sha = try Git.Sha(value: deploy.sha)
      try Id
        .make(cfg.git.listCommits(
          in: [.make(sha: sha)],
          notIn: [.make(sha: head)],
          noMerges: true,
          firstParents: false
        ))
        .map(execute)
        .map(Execute.parseLines(reply:))
        .get()
        .map(Git.Sha.init(value:))
        .forEach { lack.insert($0) }
      let shas = try Id
        .make(cfg.git.listCommits(
          in: [.make(sha: head)],
          notIn: [.make(sha: sha)],
          noMerges: true,
          firstParents: false
        ))
        .map(execute)
        .map(Execute.parseLines(reply:))
        .get()
        .map(Git.Sha.init(value:))
      uniq = uniq.get(Set(shas)).intersection(shas)
      if deploy.version != version { heir = heir.get(Set(shas)).intersection(shas) }
    }
    heir = heir.get([]).subtracting(uniq.get([]))
    let deploy = try builds.last
      .map(\.build)
      .reduce(production, cfg.bumpBuildNumber(production:build:))
      .map(generate)
      .map { product.deploy(job: gitlabCi.job, version: version, build: $0) }
      .get { throw Thrown("Push first build number manually") }
    let tag = try generate(cfg.createDeployTagName(
      product: product,
      version: version,
      build: deploy.build
    ))
    let annotation = try generate(cfg.createDeployTagAnnotation(
      product: product,
      version: version,
      build: deploy.build
    ))
    try persistBuilds(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      production: production,
      builds: builds,
      build: .deploy(deploy)
    ))
    try gitlabCi
      .postTags(name: tag, ref: gitlabCi.job.pipeline.sha, message: annotation)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try report(cfg.reportDeployTagCreated(
      ref: tag,
      product: product,
      deploy: deploy,
      uniq: makeCommitReport(cfg: cfg, shas: uniq.get([])),
      heir: makeCommitReport(cfg: cfg, shas: heir.get([])),
      lack: makeCommitReport(cfg: cfg, shas: lack)
    ))
    return true
  }
  public func reserveReviewBuild(cfg: Configuration) throws -> Bool {
    let production = try resolveProduction(.init(cfg: cfg))
    guard let ctx = try worker.resolveParentReview(cfg: cfg) else { return false }
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    guard !builds.contains(where: ctx.job.matches(build:))
    else { throw Thrown("Build already exists") }
    try persistBuilds(.init(
      cfg: cfg,
      pushUrl: ctx.gitlab.pushUrl.get(),
      production: production,
      builds: builds,
      build: try builds.last
        .map(\.build)
        .reduce(production, cfg.bumpBuildNumber(production:build:))
        .map(generate)
        .map(ctx.review.makeBuild(build:))
        .get { throw Thrown("Push first build number manually") }
    ))
    return true
  }
  public func reserveProtectedBuild(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    guard case nil = try? gitlabCi.job.review.get()
    else { throw Thrown("Protected branches merge requests not supported") }
    let production = try resolveProduction(.init(cfg: cfg))
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    guard !builds.contains(where: gitlabCi.job.matches(build:))
    else { throw Thrown("Build already exists") }
    try persistBuilds(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      production: production,
      builds: builds,
      build: try builds.last
        .map(\.build)
        .reduce(production, cfg.bumpBuildNumber(production:build:))
        .map(generate)
        .map(gitlabCi.job.makeBranchBuild(build:))
        .get { throw Thrown("Push first build number manually") }
    ))
    return true
  }
  public func createReleaseBranch(cfg: Configuration, product: String) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let product = try production.productMatching(name: product)
    try gitlabCi.job.checkPermission(users: product.mainatiners)
    let versions = try resolveProductionVersions(.init(cfg: cfg, production: production))
    let version = try versions[product.name]
      .get { throw Thrown("No version for \(product.name)") }
    let name = try generate(cfg.createReleaseBranchName(
      product: product,
      version: version
    ))
    try gitlabCi
      .postBranches(name: name, ref: gitlabCi.job.pipeline.sha)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    report(cfg.reportReleaseBranchCreated(ref: name, product: product.name, version: version))
    let next = try generate(cfg.bumpCurrentVersion(
      product: product,
      version: version
    ))
    try persistVersions(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      production: production,
      versions: versions,
      product: product,
      version: next
    ))
    report(cfg.reportVersionBumped(product: product.name, version: next))
    return true
  }
  public func createHotfixBranch(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    guard gitlabCi.job.tag else { throw Thrown("Not on tag") }
    let product = try production.productMatching(ref: gitlabCi.job.pipeline.ref, tag: true)
      .get { throw Thrown("No product match \(gitlabCi.job.pipeline.ref)") }
    try gitlabCi.job.checkPermission(users: product.mainatiners)
    let version = try generate(cfg.parseDeployTagVersion(
      product: product,
      ref: gitlabCi.job.pipeline.ref
    ))
    let hotfix = try generate(cfg.createHotfixVersion(
      product: product,
      version: version
    ))
    let name = try generate(cfg.createReleaseBranchName(
      product: product,
      version: hotfix
    ))
    try gitlabCi
      .postBranches(name: name, ref: gitlabCi.job.pipeline.sha)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    report(cfg.reportHotfixBranchCreated(ref: name, product: product.name, version: version))
    return true
  }
  public func createAccessoryBranch(
    cfg: Configuration,
    family: String,
    name: String
  ) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let accessoryBranch = try resolveProduction(.init(cfg: cfg))
      .accessoryBranches
      .first { $0.family == family }
      .get { throw Thrown("accessoryBranch \(family) not configured") }
    try gitlabCi.job.checkPermission(users: accessoryBranch.mainatiners)
    guard accessoryBranch.nameMatch.isMet(name)
    else { throw Thrown("Name does not meat \(family) criteria") }
    try gitlabCi
      .postBranches(name: name, ref: gitlabCi.job.pipeline.sha)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    report(cfg.reportAccessoryBranchCreated(family: family, ref: name))
    return true
  }
  public func renderBuild(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let build: String
    var versions = try resolveProductionVersions(.init(cfg: cfg, production: production))
    if gitlabCi.job.tag {
      let product = try production
        .productMatching(ref: gitlabCi.job.pipeline.ref, tag: true)
        .get { throw Thrown("No product for \(gitlabCi.job.pipeline.ref)") }
      build = try generate(cfg.parseDeployTagBuild(
        product: product,
        ref: gitlabCi.job.pipeline.ref
      ))
      versions[product.name] = try generate(cfg.parseReleaseBranchVersion(
        product: product,
        ref: gitlabCi.job.pipeline.ref
      ))
    } else {
      let resolved = try resolveProductionBuilds(.init(cfg: cfg, production: production))
       .reversed()
       .first(where: gitlabCi.job.matches(build:))
       .get { throw Thrown("No build number reserved") }
      build = resolved.build
      let branch = resolved.target.get(gitlabCi.job.pipeline.ref)
      if let accessory = production.accessoryBranches.first(where: { accessory in
        accessory.nameMatch.isMet(branch)
      }) {
        for (product, version) in versions {
          versions[product] = try generate(cfg.adjustAccessoryBranchVersion(
            accessoryBranch: accessory,
            ref: branch,
            product: product,
            version: version
          ))
        }
      }
      if let product = try production.productMatching(ref: branch, tag: false) {
        versions[product.name] = try generate(cfg.parseReleaseBranchVersion(
          product: product,
          ref: branch
        ))
      }
    }
    try writeStdout(generate(cfg.exportBuildContext(versions: versions, build: build)))
    return true
  }
  public func renderVersions(cfg: Configuration) throws -> Bool {
    try writeStdout(generate(cfg.exportCurrentVersions(
      versions: resolveProductionVersions(.init(
        cfg: cfg,
        production: resolveProduction(.init(cfg: cfg))
      ))
    )))
    return true
  }
  func makeCommitReport(cfg: Configuration, shas: Set<Git.Sha>) throws -> [Report.DeployTagCreated.Commit] {
    var dates: [String: UInt] = [:]
    var messages: [String: String] = [:]
    for sha in shas {
      messages[sha.value] = try Id(cfg.git.getCommitMessage(ref: .make(sha: sha)))
        .map(execute)
        .map(Execute.parseText(reply:))
        .get()
      dates[sha.value] = try Id(cfg.git.getAuthorTimestamp(ref: .make(sha: sha)))
        .map(execute)
        .map(Execute.parseText(reply:))
        .map(UInt.init(_:))
        .get()
    }
    return messages
      .map(Report.DeployTagCreated.Commit.make(sha:msg:))
      .sorted { dates[$0.sha].get(0) < dates[$1.sha].get(0) }
      .reversed()
  }
}
