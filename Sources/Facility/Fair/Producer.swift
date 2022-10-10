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
    let product = try production
      .productMatching(release: gitlabCi.job.pipeline.ref)
      .get { throw Thrown("Branch \(gitlabCi.job.pipeline.ref) matches no products") }
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
    let tag = try generate(cfg.createTagName(
      product: product,
      version: current,
      build: build,
      deploy: true
    ))
    let annotation = try generate(cfg.createTagAnnotation(
      product: product,
      version: current,
      build: build,
      deploy: true
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
    let production = try resolveProduction(.init(cfg: cfg))
    let ctx = try worker.resolveParentReview(cfg: cfg)
    let builds = try loadBuilds(cfg: cfg, production: production)
    guard !builds.values.contains(where: ctx.matches(build:)) else {
      logMessage(.init(message: "Build already exists"))
      return true
    }
    let build = try ctx.makeBuild(build: generate(cfg.bumpBuildNumber(
      production: production,
      build: builds.keys
        .sorted()
        .max()
        .map(\.value)
        .get { throw Thrown("No builds in asset") }
    )))
    try persist(cfg: cfg, production: production, builds: builds, update: build)
    return true
  }
  public func reserveBranchBuild(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let builds = try loadBuilds(cfg: cfg, production: production)
    guard gitlabCi.job.tag.not else { throw Thrown("Not on branch") }
    guard builds.values.contains(where: gitlabCi.matches(build:)).not else {
      logMessage(.init(message: "Build already exists"))
      return true
    }
    try persist(
      cfg: cfg,
      production: production,
      builds: builds,
      update: try builds.keys.max().map(\.value)
        .reduce(production, cfg.bumpBuildNumber(production:build:))
        .map(generate)
        .map(gitlabCi.job.makeBuild(build:))
        .get { throw Thrown("No builds in asset") }
    )
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
    let product = try production
      .productMatching(deploy: gitlabCi.job.pipeline.ref)
      .get { throw Thrown("Tag \(gitlabCi.job.pipeline.ref) matches no products") }
    let versions = try loadVersions(cfg: cfg, production: production)
    guard var version = versions[product.name]
    else { throw Thrown("Versioning not configured for \(product.name)") }
    let sha = try Git.Sha.make(job: gitlabCi.job)
    let current = try generate(cfg.parseTagVersion(
      product: product,
      ref: gitlabCi.job.pipeline.ref,
      deploy: true
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
    let gitlabCi = try cfg.gitlabCi.get()
    let criteria = try resolveProduction(.init(cfg: cfg)).matchAccessoryBranch
    guard criteria.isMet(name) else { throw Thrown("\(name) does not meat accessory criteria") }
    guard try gitlabCi
      .postBranches(name: name, ref: gitlabCi.job.pipeline.sha)
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
      .get()
      .protected
    else { throw Thrown("Release \(name) not protected") }
    report(cfg.reportAccessoryBranchCreated(ref: name))
    return true
  }
  public func renderBuild(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    let name = gitlabCi.job.pipeline.ref
    let build: String
    let versions = try loadVersions(cfg: cfg, production: production)
    var current = versions.mapValues(\.next.value)
    if gitlabCi.job.tag {
      let product: Production.Product
      let deploy: Bool
      if let found = try production.productMatching(deploy: name) {
        product = found
        deploy = true
      } else if let found = try production.productMatching(stage: name) {
        product = found
        deploy = false
      } else {
        throw Thrown("Not on deploy or stage tag")
      }
      build = try generate(cfg.parseTagBuild(
        product: product,
        ref: name,
        deploy: deploy
      ))
      current[product.name] = try generate(cfg.parseTagVersion(
        product: product,
        ref: name,
        deploy: deploy
      ))
    } else {
      guard let resolved = try loadBuilds(cfg: cfg, production: production)
        .values
        .first(where: gitlabCi.job.matches(build:))
      else {
        logMessage(.init(message: "No build number reserved"))
        return false
      }
      build = resolved.build.value
      if let product = try production.productMatching(release: name) {
        current[product.name] = try generate(cfg.parseReleaseBranchVersion(
          product: product,
          ref: name
        ))
      } else if production.matchAccessoryBranch.isMet(name) {
        for product in production.products.keys {
          current[product] = versions[product]?.accessories[name]?.value ?? current[product]
        }
      }
    }
    try writeStdout(generate(cfg.exportBuildContext(
      production: production,
      versions: current,
      build: build
    )))
    return true
  }
  public func renderNextVersions(cfg: Configuration) throws -> Bool {
    let production = try resolveProduction(.init(cfg: cfg))
    try writeStdout(generate(cfg.exportCurrentVersions(
      production: production,
      versions: loadVersions(cfg: cfg, production: production).mapValues(\.next.value)
    )))
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
