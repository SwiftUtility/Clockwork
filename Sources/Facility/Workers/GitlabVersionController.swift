import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
public struct GitlabVersionController {
  let execute: Try.Reply<Execute>
  let renderStencil: Try.Reply<RenderStencil>
  let writeData: Try.Reply<WriteData>
  let resolveProduction: Try.Reply<ResolveProduction>
  let resolveProductionVersions: Try.Reply<ResolveProductionVersions>
  let resolveProductionBuilds: Try.Reply<ResolveProductionBuilds>
  let persistBuilds: Try.Reply<PersistBuilds>
  let persistVersions: Try.Reply<PersistVersions>
  let sendReport: Try.Reply<SendReport>
  let logMessage: Act.Reply<LogMessage>
  let printLine: Act.Of<String>.Go
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    renderStencil: @escaping Try.Reply<RenderStencil>,
    writeData: @escaping Try.Reply<WriteData>,
    resolveProduction: @escaping Try.Reply<ResolveProduction>,
    resolveProductionVersions: @escaping Try.Reply<ResolveProductionVersions>,
    resolveProductionBuilds: @escaping Try.Reply<ResolveProductionBuilds>,
    persistBuilds: @escaping Try.Reply<PersistBuilds>,
    persistVersions: @escaping Try.Reply<PersistVersions>,
    sendReport: @escaping Try.Reply<SendReport>,
    logMessage: @escaping Act.Reply<LogMessage>,
    printLine: @escaping Act.Of<String>.Go,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.renderStencil = renderStencil
    self.writeData = writeData
    self.resolveProduction = resolveProduction
    self.resolveProductionVersions = resolveProductionVersions
    self.resolveProductionBuilds = resolveProductionBuilds
    self.persistBuilds = persistBuilds
    self.persistVersions = persistVersions
    self.sendReport = sendReport
    self.logMessage = logMessage
    self.printLine = printLine
    self.jsonDecoder = jsonDecoder
  }
  public func createDeployTag(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let job = try gitlabCi.getCurrentJob
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(_:from:))
      .get()
    guard !job.tag else { throw Thrown("Not on branch") }
    let product = try production.productMatching(ref: job.pipeline.ref, tag: false)
    try product.checkPermission(job: job)
    let version = try renderStencil(.make(generator: cfg.generateReleaseVersion(
      product: product,
      ref: job.pipeline.ref
    )))
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    let build = try builds.last
      .map(\.build)
      .reduce(production, cfg.generateNextBuild(production:build:))
      .map(RenderStencil.make(generator:))
      .map(renderStencil)
      .or { throw Thrown("Push first build number manually") }
    let tag = try renderStencil(.make(generator: cfg.generateDeployName(
      product: product,
      version: version,
      build: build
    )))
    let annotation = try renderStencil(.make(generator: cfg.generateDeployAnnotation(
      job: job,
      product: product,
      version: version,
      build: build
    )))
    try persistBuilds(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      production: production,
      builds: builds,
      build: .make(build: build, sha: job.pipeline.sha, tag: tag)
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
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(_:from:))
      .get()
    let product = try production.productMatching(name: product)
    try product.checkPermission(job: job)
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    let build = try builds.last
      .map(\.build)
      .reduce(production, cfg.generateNextBuild(production:build:))
      .map(RenderStencil.make(generator:))
      .map(renderStencil)
      .or { throw Thrown("Push first build number manually") }
    let tag = try renderStencil(.make(generator: cfg.generateDeployName(
      product: product,
      version: version,
      build: build
    )))
    let annotation = try renderStencil(.make(generator: cfg.generateDeployAnnotation(
      job: job,
      product: product,
      version: version,
      build: build
    )))
    try persistBuilds(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      production: production,
      builds: builds,
      build: .make(build: build, sha: job.pipeline.sha, tag: tag)
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
      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(_:from:))
      .get()
    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
    guard case nil = builds.first(where: { build in
      build.sha == review.pipeline.sha && review.targetBranch == build.branch
    }) else { throw Thrown("Build already exists") }
    let build = try builds.last
      .map(\.build)
      .reduce(production, cfg.generateNextBuild(production:build:))
      .map(RenderStencil.make(generator:))
      .map(renderStencil)
      .or { throw Thrown("Push first build number manually") }
    try persistBuilds(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      production: production,
      builds: builds,
      build: .make(build: build, sha: review.pipeline.sha, branch: review.targetBranch)
    ))
    return true
  }
  public func createReleaseBranch(cfg: Configuration, product: String) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let job = try gitlabCi.getCurrentJob
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(_:from:))
      .get()
    let product = try production.productMatching(name: product)
    try product.checkPermission(job: job)
    let versions = try resolveProductionVersions(.init(cfg: cfg, production: production))
    let version = try versions[product.name]
      .or { throw Thrown("No version for \(product.name)") }
    let name = try renderStencil(.make(generator: cfg.generateReleaseName(
      product: product,
      version: version
    )))
    _ = try gitlabCi
      .postBranches(name: name, ref: job.pipeline.sha)
      .map(execute)
      .get()
    let next = try renderStencil(.make(generator: cfg.generateNextVersion(
      product: product,
      version: version
    )))
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
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(_:from:))
      .get()
    guard job.tag else { throw Thrown("Not on tag") }
    let product = try production.productMatching(ref: job.pipeline.ref, tag: true)
    try product.checkPermission(job: job)
    let version = try renderStencil(.make(generator: cfg.generateDeployVersion(
      product: product,
      ref: job.pipeline.ref
    )))
    let hotfix = try renderStencil(.make(generator: cfg.generateHotfixVersion(
      product: product,
      version: version
    )))
    let name = try renderStencil(.make(generator: cfg.generateReleaseName(
      product: product,
      version: hotfix
    )))
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
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(_:from:))
      .get()
    guard job.tag else { throw Thrown("Not on tag") }
    try sendReport(cfg.makeSendReport(report: cfg.reportReleaseNotes(
      job: job,
      commits: Id
        .make(cfg.git.listCommits(
          in: [.make(sha: .init(value: job.pipeline.sha))],
          notIn: [.make(tag: tag)],
          noMerges: true,
          firstParents: false
        ))
        .map(execute)
        .map(String.make(utf8:))
        .get()
        .components(separatedBy: .newlines)
        .map(Git.Sha.init(value:))
        .map(Git.Ref.make(sha:))
        .map(cfg.git.getCommitMessage(ref:))
        .map(execute)
        .map(String.make(utf8:))
    )))
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
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(_:from:))
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
      versions[product.name] = try renderStencil(.make(generator: cfg.generateReleaseVersion(
        product: product,
        ref: target
      )))
    }
    try printLine(renderStencil(.make(generator: cfg.generateBuild(
      template: template,
      build: build.build,
      versions: versions
    ))))
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
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(_:from:))
      .get()
    let build: String
    var versions = try resolveProductionVersions(.init(cfg: cfg, production: production))
    if job.tag {
      let product = try production.productMatching(ref: job.pipeline.ref, tag: true)
      build = try renderStencil(.make(generator: cfg.generateDeployBuild(
        product: product,
        ref: job.pipeline.ref
      )))
      versions[product.name] = try renderStencil(.make(generator: cfg.generateReleaseVersion(
        product: product,
        ref: job.pipeline.ref
      )))
    } else {
      let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
      if let present =  builds.reversed().first(where: { build in
        build.sha == job.pipeline.sha && build.branch == job.pipeline.ref
      }) {
        build = present.build
      } else {
        let newBuild = try builds.last
          .map(\.build)
          .reduce(production, cfg.generateNextBuild(production:build:))
          .map(RenderStencil.make(generator:))
          .map(renderStencil)
          .or { throw Thrown("Push first build number manually") }
        try persistBuilds(.init(
          cfg: cfg,
          pushUrl: gitlabCi.pushUrl.get(),
          production: production,
          builds: builds,
          build: .make(build: newBuild, sha: job.pipeline.sha, branch: job.pipeline.ref)
        ))
        build = newBuild
      }
    }
    try printLine(renderStencil(.make(generator: cfg.generateBuild(
      template: template,
      build: build,
      versions: versions
    ))))
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
      versions[product.name] = try renderStencil(.make(generator: cfg.generateReleaseVersion(
        product: product,
        ref: target
      )))
    }
    try printLine(renderStencil(.make(generator: cfg.generateVersions(
      template: template,
      versions: versions
    ))))
    return true
  }
}
