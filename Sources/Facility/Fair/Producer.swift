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
  let report: Try.Reply<Report>
  let logMessage: Act.Reply<LogMessage>
  let printLine: Act.Of<String>.Go
  let restler: Restler
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
    report: @escaping Try.Reply<Report>,
    logMessage: @escaping Act.Reply<LogMessage>,
    printLine: @escaping Act.Of<String>.Go,
    restler: Restler,
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
    self.printLine = printLine
    self.restler = restler
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
    let version = try generate(cfg.generateReleaseVersion(
      product: product,
      ref: gitlabCi.job.pipeline.ref
    ))
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    let build = try builds.last
      .map(\.value)
      .reduce(production, cfg.generateNextBuild(production:build:))
      .map(generate)
      .get { throw Thrown("Push first build number manually") }
    let tag = try generate(cfg.generateDeployName(
      product: product,
      version: version,
      build: build
    ))
    let annotation = try generate(cfg.generateDeployAnnotation(
      product: product,
      version: version,
      build: build
    ))
    try persistBuilds(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      production: production,
      builds: builds,
      build: .make(
        value: build,
        sha: gitlabCi.job.pipeline.sha,
        tag: tag
      )
    ))
    try gitlabCi
      .postTags(parameters: .init(name: tag, ref: gitlabCi.job.pipeline.sha, message: annotation))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func createCustomDeployTag(
    cfg: Configuration,
    product: String,
    version: String
  ) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let product = try production.productMatching(name: product)
    try gitlabCi.job.checkPermission(users: product.mainatiners)
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    let build = try builds.last
      .map(\.value)
      .reduce(production, cfg.generateNextBuild(production:build:))
      .map(generate)
      .get { throw Thrown("Push first build number manually") }
    let tag = try generate(cfg.generateDeployName(
      product: product,
      version: version,
      build: build
    ))
    let annotation = try generate(cfg.generateDeployAnnotation(
      product: product,
      version: version,
      build: build
    ))
    try persistBuilds(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      production: production,
      builds: builds,
      build: .make(
        value: build,
        sha: gitlabCi.job.pipeline.sha,
        tag: tag
      )
    ))
    try gitlabCi
      .postTags(parameters: .init(name: tag, ref: gitlabCi.job.pipeline.sha, message: annotation))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func reserveReviewBuild(cfg: Configuration) throws -> Bool {
    let production = try resolveProduction(.init(cfg: cfg))
    guard let ctx = try restler.resolveParentReview(cfg: cfg) else { return false }
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    guard !builds.contains(where: ctx.review.matches(build:))
    else { throw Thrown("Build already exists") }
    try persistBuilds(.init(
      cfg: cfg,
      pushUrl: ctx.gitlab.pushUrl.get(),
      production: production,
      builds: builds,
      build: .make(
        value: try builds.last
          .map(\.value)
          .reduce(production, cfg.generateNextBuild(production:build:))
          .map(generate)
          .get { throw Thrown("Push first build number manually") },
        sha: ctx.review.pipeline.sha,
        targer: ctx.review.targetBranch,
        review: ctx.review.iid
      )
    ))
    return true
  }
  public func reserveBranchBuild(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    guard !gitlabCi.job.tag else { throw Thrown("Must be branch job") }
    let production = try resolveProduction(.init(cfg: cfg))
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    guard !builds.contains(where: gitlabCi.job.matches(build:))
    else { throw Thrown("Build already exists") }
    try persistBuilds(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      production: production,
      builds: builds,
      build: .make(
        value: try builds.last
          .map(\.value)
          .reduce(production, cfg.generateNextBuild(production:build:))
          .map(generate)
          .get { throw Thrown("Push first build number manually") },
        sha: gitlabCi.job.pipeline.sha,
        branch: gitlabCi.job.pipeline.ref
      )
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
    let name = try generate(cfg.generateReleaseName(
      product: product,
      version: version
    ))
    try gitlabCi
      .postBranches(name: name, ref: gitlabCi.job.pipeline.sha)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    let next = try generate(cfg.generateNextVersion(
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
    return true
  }
  public func createHotfixBranch(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    guard gitlabCi.job.tag else { throw Thrown("Not on tag") }
    let product = try production.productMatching(ref: gitlabCi.job.pipeline.ref, tag: true)
      .get { throw Thrown("No product match \(gitlabCi.job.pipeline.ref)") }
    try gitlabCi.job.checkPermission(users: product.mainatiners)
    let version = try generate(cfg.generateDeployVersion(
      product: product,
      ref: gitlabCi.job.pipeline.ref
    ))
    let hotfix = try generate(cfg.generateHotfixVersion(
      product: product,
      version: version
    ))
    let name = try generate(cfg.generateReleaseName(
      product: product,
      version: hotfix
    ))
    try gitlabCi
      .postBranches(name: name, ref: gitlabCi.job.pipeline.sha)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func createCustomBranch(cfg: Configuration, custom: String) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let accessoryBranch = try resolveProduction(.init(cfg: cfg)).accessoryBranch.get()
    try gitlabCi.job.checkPermission(users: accessoryBranch.mainatiners)
    try gitlabCi
      .postBranches(
        name: generate(cfg.generateAccessoryName(
          accessoryBranch: accessoryBranch,
          custom: custom
        )),
        ref: gitlabCi.job.pipeline.sha
      )
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func reportReleaseNotes(cfg: Configuration, tag: String) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    guard gitlabCi.job.tag else { throw Thrown("Not on tag") }
    try report(cfg.reportReleaseNotes(
      commits: Id
        .make(cfg.git.listCommits(
          in: [.make(sha: .init(value: gitlabCi.job.pipeline.sha))],
          notIn: [.make(tag: tag)],
          noMerges: true,
          firstParents: false
        ))
        .map(execute)
        .map(Execute.parseLines(reply:))
        .get()
        .map(Git.Sha.init(value:))
        .map(Git.Ref.make(sha:))
        .map(cfg.git.getCommitMessage(ref:))
        .map(execute)
        .map(Execute.parseText(reply:))
    ))
    return true
  }
  public func renderReviewBuild(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    guard let build = builds.reversed().first(where: gitlabCi.job.matches(build:)) else {
      logMessage(.init(message: "Build number not reserved"))
      return false
    }
    var versions = try resolveProductionVersions(.init(cfg: cfg, production: production))
    if let product = try? production.productMatching(ref: build.ref, tag: false) {
      versions[product.name] = try generate(cfg.generateReleaseVersion(
        product: product,
        ref: build.ref
      ))
    }
    try printLine(generate(cfg.generateBuild(versions: versions, build: build)))
    return true
  }
  public func renderProtectedBuild(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let build: Production.Build
    var versions = try resolveProductionVersions(.init(cfg: cfg, production: production))
    if gitlabCi.job.tag {
      let product = try production
        .productMatching(ref: gitlabCi.job.pipeline.ref, tag: true)
        .get { throw Thrown("No product for \(gitlabCi.job.pipeline.ref)") }
      build = .make(
        value: try generate(cfg.generateDeployBuild(
          product: product,
          ref: gitlabCi.job.pipeline.ref
        )),
        sha: gitlabCi.job.pipeline.sha,
        tag: gitlabCi.job.pipeline.ref
      )
      versions[product.name] = try generate(cfg.generateReleaseVersion(
        product: product,
        ref: gitlabCi.job.pipeline.ref
      ))
    } else {
      build = try resolveProductionBuilds(.init(cfg: cfg, production: production))
       .reversed()
       .first(where: gitlabCi.job.matches(build:))
       .get { throw Thrown("No build number reserved") }
      if let product = try production.productMatching(ref: gitlabCi.job.pipeline.ref, tag: false) {
        versions[product.name] = try generate(cfg.generateReleaseVersion(
          product: product,
          ref: gitlabCi.job.pipeline.ref
        ))
      }
    }
    try printLine(generate(cfg.generateBuild(versions: versions, build: build)))
    return true
  }
  public func renderVersions(cfg: Configuration) throws -> Bool {
    try printLine(generate(cfg.generateVersions(
      versions: resolveProductionVersions(.init(
        cfg: cfg,
        production: resolveProduction(.init(cfg: cfg))
      ))
    )))
    return true
  }
}
