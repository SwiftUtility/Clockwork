import Foundation
import Facility
import FacilityPure
public struct GitlabVersionController {
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
    self.jsonDecoder = jsonDecoder
  }
  public func createDeployTag(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let job = try gitlabCi.getCurrentJob
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    guard !job.tag else { throw Thrown("Not on branch") }
    let product = try production.productMatching(ref: job.pipeline.ref, tag: false)
    try product.checkPermission(job: job)
    let version = try generate(cfg.generateReleaseVersion(
      product: product,
      ref: job.pipeline.ref
    ))
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    let build = try builds.last
      .map(\.value)
      .reduce(production, cfg.generateNextBuild(production:build:))
      .map(generate)
      .or { throw Thrown("Push first build number manually") }
    let tag = try generate(cfg.generateDeployName(
      product: product,
      version: version,
      build: build
    ))
    let annotation = try generate(cfg.generateDeployAnnotation(
      job: job,
      product: product,
      version: version,
      build: build
    ))
    try persistBuilds(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      production: production,
      builds: builds,
      build: .make(value: build, sha: job.pipeline.sha, ref: .tag(tag))
    ))
    _ = try gitlabCi
      .postTags(parameters: .init(name: tag, ref: job.pipeline.sha, message: annotation))
      .map(execute)
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
    let job = try gitlabCi.getCurrentJob
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    let product = try production.productMatching(name: product)
    try product.checkPermission(job: job)
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    let build = try builds.last
      .map(\.value)
      .reduce(production, cfg.generateNextBuild(production:build:))
      .map(generate)
      .or { throw Thrown("Push first build number manually") }
    let tag = try generate(cfg.generateDeployName(
      product: product,
      version: version,
      build: build
    ))
    let annotation = try generate(cfg.generateDeployAnnotation(
      job: job,
      product: product,
      version: version,
      build: build
    ))
    try persistBuilds(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      production: production,
      builds: builds,
      build: .make(value: build, sha: job.pipeline.sha, ref: .tag(tag))
    ))
    _ = try gitlabCi
      .postTags(parameters: .init(name: tag, ref: job.pipeline.sha, message: annotation))
      .map(execute)
      .get()
    return true
  }
  public func reserveReviewBuild(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let review = try gitlabCi.getParentMrState
      .map(execute)
      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
      .get()
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    guard case nil = builds.first(where: { build in
      build.sha == review.pipeline.sha && review.targetBranch == build.branch
    }) else { throw Thrown("Build already exists") }
    let build = try builds.last
      .map(\.value)
      .reduce(production, cfg.generateNextBuild(production:build:))
      .map(generate)
      .or { throw Thrown("Push first build number manually") }
    try persistBuilds(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      production: production,
      builds: builds,
      build: .make(value: build, sha: review.pipeline.sha, ref: .branch(review.targetBranch))
    ))
    return true
  }
  public func createReleaseBranch(cfg: Configuration, product: String) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let job = try gitlabCi.getCurrentJob
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    let product = try production.productMatching(name: product)
    try product.checkPermission(job: job)
    let versions = try resolveProductionVersions(.init(cfg: cfg, production: production))
    let version = try versions[product.name]
      .or { throw Thrown("No version for \(product.name)") }
    let name = try generate(cfg.generateReleaseName(
      product: product,
      version: version
    ))
    _ = try gitlabCi
      .postBranches(name: name, ref: job.pipeline.sha)
      .map(execute)
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
    let job = try gitlabCi.getCurrentJob
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    guard job.tag else { throw Thrown("Not on tag") }
    let product = try production.productMatching(ref: job.pipeline.ref, tag: true)
    try product.checkPermission(job: job)
    let version = try generate(cfg.generateDeployVersion(
      product: product,
      ref: job.pipeline.ref
    ))
    let hotfix = try generate(cfg.generateHotfixVersion(
      product: product,
      version: version
    ))
    let name = try generate(cfg.generateReleaseName(
      product: product,
      version: hotfix
    ))
    _ = try gitlabCi
      .postBranches(name: name, ref: job.pipeline.sha)
      .map(execute)
      .get()
    return true
  }
  public func reportReleaseNotes(cfg: Configuration, tag: String) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let job = try gitlabCi.getCurrentJob
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    guard job.tag else { throw Thrown("Not on tag") }
    try report(cfg.reportReleaseNotes(
      job: job,
      commits: Id
        .make(cfg.git.listCommits(
          in: [.make(sha: .init(value: job.pipeline.sha))],
          notIn: [.make(tag: tag)],
          noMerges: true,
          firstParents: false
        ))
        .map(execute)
        .map(Execute.successLines(reply:))
        .get()
        .map(Git.Sha.init(value:))
        .map(Git.Ref.make(sha:))
        .map(cfg.git.getCommitMessage(ref:))
        .map(execute)
        .map(Execute.successText(reply:))
    ))
    return true
  }
  public func renderReviewBuild(
    cfg: Configuration,
    template: String
  ) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let job = try gitlabCi.getCurrentJob
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    let target = try gitlabCi.reviewTarget.or { throw Thrown("Not in review context") }
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    guard let build = builds.reversed().first(where: { build in
      build.sha == job.pipeline.sha && build.branch == target
    }) else {
      logMessage(.init(message: "Build number not reserved"))
      return false
    }
    var versions = try resolveProductionVersions(.init(cfg: cfg, production: production))
    if let product = try? production.productMatching(ref: target, tag: false) {
      versions[product.name] = try generate(cfg.generateReleaseVersion(
        product: product,
        ref: target
      ))
    }
    try printLine(generate(cfg.generateBuild(
      template: template,
      build: build.value,
      versions: versions
    )))
    return true
  }
  public func renderBuild(
    cfg: Configuration,
    template: String
  ) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let job = try gitlabCi.getCurrentJob
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    let build: String
    var versions = try resolveProductionVersions(.init(cfg: cfg, production: production))
    if job.tag {
      let product = try production.productMatching(ref: job.pipeline.ref, tag: true)
      build = try generate(cfg.generateDeployBuild(
        product: product,
        ref: job.pipeline.ref
      ))
      versions[product.name] = try generate(cfg.generateReleaseVersion(
        product: product,
        ref: job.pipeline.ref
      ))
    } else {
      let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
      if let present =  builds.reversed().first(where: { build in
        build.sha == job.pipeline.sha && build.branch == job.pipeline.ref
      }) {
        build = present.value
      } else {
        let newBuild = try builds.last
          .map(\.value)
          .reduce(production, cfg.generateNextBuild(production:build:))
          .map(generate)
          .or { throw Thrown("Push first build number manually") }
        try persistBuilds(.init(
          cfg: cfg,
          pushUrl: gitlabCi.pushUrl.get(),
          production: production,
          builds: builds,
          build: .make(value: newBuild, sha: job.pipeline.sha, ref: .branch(job.pipeline.ref))
        ))
        build = newBuild
      }
    }
    try printLine(generate(cfg.generateBuild(
      template: template,
      build: build,
      versions: versions
    )))
    return true
  }
  public func renderVersions(
    cfg: Configuration,
    template: String
  ) throws -> Bool {
    let production = try resolveProduction(.init(cfg: cfg))
    var versions = try resolveProductionVersions(.init(cfg: cfg, production: production))
    if
      let target = try? cfg.controls.gitlabCi.map(\.reviewTarget).get(),
      let product = try? production.productMatching(ref: target, tag: false)
    {
      versions[product.name] = try generate(cfg.generateReleaseVersion(
        product: product,
        ref: target
      ))
    }
    try printLine(generate(cfg.generateVersions(
      template: template,
      versions: versions
    )))
    return true
  }
}
