import Foundation
import Facility
import FacilityPure
public final class Producer {
  let execute: Try.Reply<Execute>
  let generate: Try.Reply<Generate>
  let writeFile: Try.Reply<Files.WriteFile>
  let resolveProduction: Try.Reply<Configuration.ResolveProduction>
  let parseBuilds: Try.Reply<Configuration.ParseYamlFile<Yaml.Production.Builds>>
  let parseVersions: Try.Reply<Configuration.ParseYamlFile<Yaml.Production.Versions>>
  let persistAsset: Try.Reply<Configuration.PersistAsset>
  let report: Act.Reply<Report>
  let createThread: Try.Reply<Report.CreateThread>
  let logMessage: Act.Reply<LogMessage>
  let writeStdout: Act.Of<String>.Go
  let worker: Worker
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    generate: @escaping Try.Reply<Generate>,
    writeFile: @escaping Try.Reply<Files.WriteFile>,
    resolveProduction: @escaping Try.Reply<Configuration.ResolveProduction>,
    parseBuilds: @escaping Try.Reply<Configuration.ParseYamlFile<Yaml.Production.Builds>>,
    parseVersions: @escaping Try.Reply<Configuration.ParseYamlFile<Yaml.Production.Versions>>,
    persistAsset: @escaping Try.Reply<Configuration.PersistAsset>,
    report: @escaping Act.Reply<Report>,
    createThread: @escaping Try.Reply<Report.CreateThread>,
    logMessage: @escaping Act.Reply<LogMessage>,
    writeStdout: @escaping Act.Of<String>.Go,
    worker: Worker,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.generate = generate
    self.writeFile = writeFile
    self.resolveProduction = resolveProduction
    self.parseBuilds = parseBuilds
    self.parseVersions = parseVersions
    self.persistAsset = persistAsset
    self.report = report
    self.createThread = createThread
    self.logMessage = logMessage
    self.writeStdout = writeStdout
    self.worker = worker
    self.jsonDecoder = jsonDecoder
  }
  public func createDeployTag(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    guard !gitlabCi.job.tag else { throw Thrown("Not on branch") }
    let product = try production.productMatching(release: gitlabCi.job.pipeline.ref)
    let current = try generate(cfg.parseReleaseBranchVersion(
      product: product,
      ref: gitlabCi.job.pipeline.ref
    ))
    let sha = try Git.Sha.make(job: gitlabCi.job)
    let versions = try loadVersions(cfg: cfg, production: production)
    guard var version = versions[product.name]
    else { throw Thrown("Versioning not configured for \(product)") }
    let delivery = try version.deploy(version: current, sha: sha)
    let builds = try loadBuilds(cfg: cfg, production: production)
    guard let build = try builds.keys.max().map(\.value)
      .reduce(production, cfg.bumpBuildNumber(production:build:))
      .map(generate)
    else { throw Thrown("No builds in asset") }
    let tag = try generate(cfg.createDeployTagName(
      product: product,
      version: current,
      build: build
    ))
    let annotation = try generate(cfg.createDeployTagAnnotation(
      product: product,
      version: current,
      build: build
    ))
    try persist(cfg: cfg, production: production, builds: builds, update: .tag(.make(
      build: build.alphaNumeric,
      sha: sha.value,
      tag: tag
    )))
    try persist(
      cfg: cfg,
      production: production,
      product: product,
      versions: versions,
      update: version,
      version: current,
      reason: .deploy
    )
    try gitlabCi
      .postTags(name: tag, ref: gitlabCi.job.pipeline.sha, message: annotation)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try report(cfg.reportDeployTagCreated(
      product: product,
      delivery: delivery,
      ref: tag,
      sha: sha.value,
      version: current,
      build: build,
      notes: makeNotes(cfg: cfg, production: production, sha: sha, delivery: delivery)
    ))
    return true
  }
  public func reserveReviewBuild(cfg: Configuration) throws -> Bool {
#warning("tbd")
//    let production = try resolveProduction(.init(cfg: cfg))
//    let ctx = try worker.resolveParentReview(cfg: cfg)
//    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
//    guard !builds.contains(where: ctx.matches(build:))
//    else {
//      logMessage(.init(message: "Build already exists"))
//      return true
//    }
//    try persistBuilds(
//      cfg: cfg,
//      production: production,
//      builds: builds,
//      build: try builds.last
//        .map(\.build)
//        .reduce(production, cfg.bumpBuildNumber(production:build:))
//        .map(generate)
//        .map(ctx.makeBuild(build:))
//        .get { throw Thrown("Push first build number manually") }
//    )
    return true
  }
  public func reserveBranchBuild(cfg: Configuration) throws -> Bool {
#warning("tbd")
//    let gitlabCi = try cfg.gitlabCi.get()
//    guard case nil = try? gitlabCi.job.review.get()
//    else { throw Thrown("Protected branches merge requests not supported") }
//    let production = try resolveProduction(.init(cfg: cfg))
//    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
//    guard !builds.contains(where: gitlabCi.matches(build:)) else {
//      logMessage(.init(message: "Build already exists"))
//      return true
//    }
//    try persistBuilds(
//      cfg: cfg,
//      production: production,
//      builds: builds,
//      build: try builds.last
//        .map(\.build)
//        .reduce(production, cfg.bumpBuildNumber(production:build:))
//        .map(generate)
//        .map(gitlabCi.job.makeBranchBuild(build:))
//        .get { throw Thrown("Push first build number manually") }
//    )
    return true
  }
  public func createReleaseBranch(cfg: Configuration, product: String) throws -> Bool {
    let gitlabCi = try cfg.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    guard let product = production.products[product]
    else { throw Thrown("Produnc \(product) not configured") }
    let versions = try loadVersions(cfg: cfg, production: production)
    guard var version = versions[product.name]
    else { throw Thrown("Versioning not configured for \(product)") }
    let current = version.next.value
    let branch = try Git.Branch(name: generate(cfg.createReleaseBranchName(
      product: product,
      version: current,
      hotfix: false
    )))
    let bump = try generate(cfg.bumpReleaseVersion(
      product: product,
      version: current,
      hotfix: false
    ))
    let sha = try Git.Sha.make(job: gitlabCi.job)
    try version.check(bump: bump)
    guard try gitlabCi
      .postBranches(name: branch.name, ref: gitlabCi.job.pipeline.sha)
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
      .get()
      .protected
    else { throw Thrown("Release \(branch) not protected") }
    let thread = try createThread(cfg.reportReleaseBranchCreated(
      product: product,
      ref: branch.name,
      version: current,
      hotfix: false
    ))
    let delivery = version.release(bump: bump, start: sha, thread: thread)
    try persist(
      cfg: cfg,
      production: production,
      product: product,
      versions: versions,
      update: version,
      version: current,
      reason: .release
    )
    try report(cfg.reportReleaseBranchSummary(
      product: product,
      delivery: delivery,
      ref: branch.name,
      sha: sha.value,
      notes: makeNotes(cfg: cfg, production: production, sha: sha, delivery: delivery))
    )
    return true
  }
  public func createHotfixBranch(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    guard gitlabCi.job.tag else { throw Thrown("Not on tag") }
    let product = try production.productMatching(deploy: gitlabCi.job.pipeline.ref)
    let versions = try loadVersions(cfg: cfg, production: production)
    guard var version = versions[product.name]
    else { throw Thrown("Versioning not configured for \(product.name)") }
    let sha = try Git.Sha.make(job: gitlabCi.job)
    let current = try generate(cfg.parseDeployTagVersion(
      product: product,
      ref: gitlabCi.job.pipeline.ref
    ))
    let hotfix = try generate(cfg.bumpReleaseVersion(
      product: product,
      version: current,
      hotfix: true
    ))
    let branch = try generate(cfg.createReleaseBranchName(
      product: product,
      version: hotfix,
      hotfix: true
    ))
    try version.check(hotfix: hotfix, of: current)
    guard try gitlabCi
      .postBranches(name: branch, ref: gitlabCi.job.pipeline.sha)
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
      .get()
      .protected
    else { throw Thrown("Hotfix \(branch) not protected") }
    let thread = try createThread(cfg.reportReleaseBranchCreated(
      product: product,
      ref: branch,
      version: hotfix,
      hotfix: true
    ))
    let delivery = version.hotfix(version: hotfix, start: sha, thread: thread)
    try persist(
      cfg: cfg,
      production: production,
      product: product,
      versions: versions,
      update: version,
      version: current,
      reason: .hotfix
    )
    try report(cfg.reportReleaseBranchSummary(
      product: product,
      delivery: delivery,
      ref: branch,
      sha: sha.value,
      notes: makeNotes(cfg: cfg, production: production, sha: sha, delivery: delivery))
    )
    return true
  }
  public func createAccessoryBranch(
    cfg: Configuration,
    name: String
  ) throws -> Bool {
#warning("tbd")
//    let gitlabCi = try cfg.gitlabCi.get()
//    let accessoryBranch = try resolveProduction(.init(cfg: cfg))
//      .accessoryBranch
//      .get { throw Thrown("accessoryBranch not configured") }
//    guard accessoryBranch.nameMatch.isMet(name)
//    else { throw Thrown("\(name) does not meat accessory criteria") }
//    try gitlabCi
//      .postBranches(name: name, ref: gitlabCi.job.pipeline.sha)
//      .map(execute)
//      .map(Execute.checkStatus(reply:))
//      .get()
//    report(cfg.reportAccessoryBranchCreated(ref: name))
    return true
  }
  public func renderBuild(cfg: Configuration) throws -> Bool {
#warning("tbd")
//    let gitlabCi = try cfg.gitlabCi.get()
//    let production = try resolveProduction(.init(cfg: cfg))
//    let build: String
//    var versions = try resolveProductionVersions(.init(cfg: cfg, production: production))
//    if gitlabCi.job.tag {
//      let product = try production
//        .productMatching(ref: gitlabCi.job.pipeline.ref, tag: true)
//        .get { throw Thrown("No product for \(gitlabCi.job.pipeline.ref)") }
//      build = try generate(cfg.parseDeployTagBuild(
//        production: production,
//        ref: gitlabCi.job.pipeline.ref
//      ))
//      versions[product.name] = try generate(cfg.parseDeployTagVersion(
//        production: production,
//        ref: gitlabCi.job.pipeline.ref
//      ))
//    } else {
//      guard let resolved = try resolveProductionBuilds(.init(cfg: cfg, production: production))
//       .reversed()
//       .first(where: gitlabCi.job.matches(build:))
//      else {
//        logMessage(.init(message: "No build number reserved"))
//        return false
//      }
//      build = resolved.build
//      let branch = resolved.target.get(gitlabCi.job.pipeline.ref)
//      if let accessory = production.accessoryBranch {
//        for (product, version) in versions {
//          versions[product] = try generate(cfg.adjustAccessoryBranchVersion(
//            accessoryBranch: accessory,
//            ref: branch,
//            product: product,
//            version: version
//          ))
//        }
//      }
//      if let product = try production.productMatching(ref: branch, tag: false) {
//        versions[product.name] = try generate(cfg.parseReleaseBranchVersion(
//          production: production,
//          ref: branch
//        ))
//      }
//    }
//    try writeStdout(generate(cfg.exportBuildContext(
//      production: production,
//      versions: versions,
//      build: build
//    )))
    return true
  }
  public func renderVersions(cfg: Configuration) throws -> Bool {
#warning("tbd")
//    let production = try resolveProduction(.init(cfg: cfg))
//    try writeStdout(generate(cfg.exportCurrentVersions(
//      production: production,
//      versions: resolveProductionVersions(.init(
//        cfg: cfg,
//        production: resolveProduction(.init(cfg: cfg))
//      ))
//    )))
    return true
  }
  func makeNotes(
    cfg: Configuration,
    production: Production,
    sha: Git.Sha,
    delivery: Production.Version.Delivery
  ) throws -> Production.ReleaseNotes {
    let previous = try Execute
      .parseLines(reply: execute(cfg.git.excludeParents(shas: delivery.previous)))
      .reduce(into: [], { try $0.append(Git.Ref.make(sha: .make(value: $1))) })
    guard previous.isEmpty.not else { return .make(uniq: [], lack: []) }
    return try Production.ReleaseNotes.make(
      uniq: Execute
        .parseLines(reply: execute(cfg.git.listCommits(
          in: [.make(sha: sha)],
          notIn: previous,
          ignoreMissing: true
        )))
        .compactMap({ sha in try production.makeNote(sha: sha, msg: Execute.parseText(
          reply: execute(cfg.git.getCommitMessage(ref: .make(sha: .make(value: sha))))
        ))}),
      lack: Execute
        .parseLines(reply: execute(cfg.git.listCommits(
          in: previous,
          notIn: [.make(sha: sha)],
          ignoreMissing: true
        )))
        .compactMap({ sha in try production.makeNote(sha: sha, msg: Execute.parseText(
          reply: execute(cfg.git.getCommitMessage(ref: .make(sha: .make(value: sha))))
        ))})
    )
  }
  func persist(
    cfg: Configuration,
    production: Production,
    builds: [AlphaNumeric: Production.Build],
    update: Production.Build
  ) throws {
    var builds = builds
    guard builds.keys.filter({ !($0 < update.build) }).isEmpty
    else { throw Thrown("Build \(update) is not the highest") }
    builds[update.build] = update
    _ = try persistAsset(.init(
      cfg: cfg,
      asset: production.builds,
      content: production.serialize(builds: builds),
      message: generate(cfg.createBuildCommitMessage(
        production: production,
        build: update
      ))
    ))
  }
  func persist(
    cfg: Configuration,
    production: Production,
    product: Production.Product,
    versions: [String: Production.Version],
    update: Production.Version,
    version: String,
    reason: Generate.CreateVersionsCommitMessage.Reason
  ) throws {
    var versions = versions
    versions[update.product] = update
    _ = try persistAsset(.init(
      cfg: cfg,
      asset: production.versions,
      content: production.serialize(versions: versions),
      message: generate(cfg.createVersionsCommitMessage(
        production: production,
        product: product,
        version: version,
        reason: reason
      ))
    ))
  }
  func loadVersions(
    cfg: Configuration,
    production: Production
  ) throws -> [String: Production.Version] {
    try parseVersions(.init(git: cfg.git, file: .make(asset: production.versions)))
      .map(Production.Version.make(product:yaml:))
      .reduce(into: [:], { $0[$1.product] = $1 })
  }
  func loadBuilds(
    cfg: Configuration,
    production: Production
  ) throws -> [AlphaNumeric: Production.Build] {
    try parseBuilds(.init(git: cfg.git, file: .make(asset: production.builds)))
      .map(Production.Build.make(build:yaml:))
      .reduce(into: [:], { $0[$1.build] = $1 })
  }
}
