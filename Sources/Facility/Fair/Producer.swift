import Foundation
import Facility
import FacilityPure
public final class Producer {
  let execute: Try.Reply<Execute>
  let generate: Try.Reply<Generate>
  let writeFile: Try.Reply<Files.WriteFile>
  let resolveProduction: Try.Reply<Configuration.ResolveProduction>
  let resolveProductionBuilds: Try.Reply<Configuration.ResolveProductionBuilds>
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
    resolveProductionBuilds: @escaping Try.Reply<Configuration.ResolveProductionBuilds>,
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
    self.resolveProductionBuilds = resolveProductionBuilds
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
//    let product = try production.productMatching(deploy: <#T##String#>)
//      .productMatching(ref: gitlabCi.job.pipeline.ref, tag: false)
//      .get { throw Thrown("No product matches \(gitlabCi.job.pipeline.ref)") }
//    let version = try generate(cfg.parseReleaseBranchVersion(
//      production: production,
//      ref: gitlabCi.job.pipeline.ref
//    ))
//    let builds = try resolveProductionBuilds(.init(cfg: cfg, production: production))
//    let head = try Git.Sha.make(value: gitlabCi.job.pipeline.sha)
//    var uniq: Set<Git.Sha>? = nil
//    var heir: Set<Git.Sha>? = nil
//    var lack: Set<Git.Sha> = []
//    for build in builds.reversed() {
//      guard case .deploy(let deploy) = build, deploy.product == product.name else { continue }
//      let sha = try Git.Sha.make(value: deploy.sha)
//      try Id
//        .make(cfg.git.listCommits(
//          in: [.make(sha: sha)],
//          notIn: [.make(sha: head)],
//          noMerges: true,
//          firstParents: false
//        ))
//        .map(execute)
//        .map(Execute.parseLines(reply:))
//        .get()
//        .map(Git.Sha.make(value:))
//        .forEach { lack.insert($0) }
//      let shas = try Id
//        .make(cfg.git.listCommits(
//          in: [.make(sha: head)],
//          notIn: [.make(sha: sha)],
//          noMerges: true,
//          firstParents: false
//        ))
//        .map(execute)
//        .map(Execute.parseLines(reply:))
//        .get()
//        .map(Git.Sha.make(value:))
//      uniq = uniq.get(Set(shas)).intersection(shas)
//      if deploy.version != version { heir = heir.get(Set(shas)).intersection(shas) }
//    }
//    heir = heir.get([]).subtracting(uniq.get([]))
//    let deploy = try builds.last
//      .map(\.build)
//      .reduce(production, cfg.bumpBuildNumber(production:build:))
//      .map(generate)
//      .map { product.deploy(job: gitlabCi.job, version: version, build: $0) }
//      .get { throw Thrown("Push first build number manually") }
//    let name = try generate(cfg.createDeployTagName(
//      production: production,
//      product: product,
//      version: version,
//      build: deploy.build
//    ))
//    guard product.deployTagNameMatch.isMet(name)
//    else { throw Thrown("\(name) does not meat deployTag criteria") }
//    let annotation = try generate(cfg.createDeployTagAnnotation(
//      production: production,
//      product: product,
//      version: version,
//      build: deploy.build
//    ))
//    try persistBuilds(
//      cfg: cfg,
//      production: production,
//      builds: builds,
//      build: .deploy(deploy)
//    )
//    try gitlabCi
//      .postTags(name: name, ref: gitlabCi.job.pipeline.sha, message: annotation)
//      .map(execute)
//      .map(Execute.checkStatus(reply:))
//      .get()
//    try report(cfg.reportDeployTagCreated(
//      ref: name,
//      product: product,
//      deploy: deploy,
//      uniq: makeCommitReport(cfg: cfg, product: product, shas: uniq.get([])),
//      heir: makeCommitReport(cfg: cfg, product: product, shas: heir.get([])),
//      lack: makeCommitReport(cfg: cfg, product: product, shas: lack)
//    ))
#warning("tbd")
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
    var versions = try loadVersions(cfg: cfg, product: product)
    let current = versions.next
    guard versions.deliveries[current] == nil
    else { throw Thrown("Release \(product) \(current) already exists") }
    let branch = try Git.Branch(name: generate(cfg.createReleaseBranchName(
      product: product,
      version: current
    )))
    let next = try generate(cfg.bumpCurrentVersion(
      product: product,
      version: current
    ))
    try gitlabCi
      .postBranches(name: branch.name, ref: gitlabCi.job.pipeline.sha)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    let thread = try createThread(cfg.reportReleaseBranchCreated(
      product: product,
      ref: branch.name,
      version: current
    ))
    let sha = try Git.Sha.make(job: gitlabCi.job)
    let delivery = versions.release(next: next, start: sha, branch: branch, thread: thread)
    _ = try persistAsset(.init(
      cfg: cfg,
      asset: product.versions,
      content: versions.serialize(),
      message: try generate(cfg.createVersionsCommitMessage(
        product: product,
        version: current
      ))
    ))
    try report(cfg.reportReleaseBranchSummary(
      product: product,
      delivery: delivery,
      notes: makeNotes(cfg: cfg, production: production, sha: sha, delivery: delivery))
    )
    return true
  }
  public func createHotfixBranch(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.gitlabCi.get()
    let production = try resolveProduction(.init(cfg: cfg))
    guard gitlabCi.job.tag else { throw Thrown("Not on tag") }
    let product = try production.productMatching(deploy: gitlabCi.job.pipeline.ref)
    var versions = try loadVersions(cfg: cfg, product: product)
    let version = try generate(cfg.parseDeployTagVersion(
      product: product,
      ref: gitlabCi.job.pipeline.ref
    ))
    guard versions.deliveries[version] != nil
    else { throw Thrown("Release \(product) \(version) does not exist") }
    let hotfix = try generate(cfg.createHotfixVersion(
      product: product,
      version: version
    ))
    guard versions.deliveries[hotfix] == nil
    else { throw Thrown("Release \(product) \(hotfix) already exists") }
    let branch = try Git.Branch(name: generate(cfg.createHotfixBranchName(
      product: product,
      version: hotfix
    )))
    try gitlabCi
      .postBranches(name: branch.name, ref: gitlabCi.job.pipeline.sha)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    let thread = try createThread(cfg.reportHotfixBranchCreated(
      product: product,
      ref: branch.name,
      version: hotfix
    ))
    let sha = try Git.Sha.make(job: gitlabCi.job)
    let delivery = try versions.hotfix(
      from: version,
      version: hotfix,
      start: sha,
      branch: branch,
      thread: thread
    )
    _ = try persistAsset(.init(
      cfg: cfg,
      asset: product.versions,
      content: versions.serialize(),
      message: try generate(cfg.createVersionsCommitMessage(
        product: product,
        version: hotfix
      ))
    ))
    try report(cfg.reportReleaseBranchSummary(
      product: product,
      delivery: delivery,
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
    delivery: Production.Versions.Delivery
  ) throws -> Production.ReleaseNotes {
    let deploys = try Execute
      .parseLines(reply: execute(cfg.git.excludeParents(shas: delivery.deploys)))
      .reduce(into: [], { try $0.append(Git.Ref.make(sha: .make(value: $1))) })
    return try Production.ReleaseNotes.make(
      uniq: Execute
        .parseLines(reply: execute(cfg.git.listCommits(
          in: [.make(sha: sha)],
          notIn: deploys,
          ignoreMissing: true
        )))
        .compactMap({ sha in try production.makeNote(sha: sha, msg: Execute.parseText(
          reply: execute(cfg.git.getCommitMessage(ref: .make(sha: .make(value: sha))))
        ))}),
      lack: Execute
        .parseLines(reply: execute(cfg.git.listCommits(
          in: deploys,
          notIn: [.make(sha: sha)],
          ignoreMissing: true
        )))
        .compactMap({ sha in try production.makeNote(sha: sha, msg: Execute.parseText(
          reply: execute(cfg.git.getCommitMessage(ref: .make(sha: .make(value: sha))))
        ))})
    )
  }
  func persistBuilds(
    cfg: Configuration,
    production: Production,
    builds: [Production.Build],
    build: Production.Build
  ) throws {
    let builds = builds + [build]
    _ = try persistAsset(.init(
      cfg: cfg,
      asset: production.builds,
      content: builds
        .suffix(production.buildsCount)
        .map(\.yaml)
        .joined(),
      message: generate(cfg.createBuildCommitMessage(
        production: production,
        build: build.build
      ))
    ))
  }
  func loadVersions(
    cfg: Configuration,
    product: Production.Product
  ) throws -> Production.Versions { try Id
    .make(.init(git: cfg.git, file: .make(asset: product.versions)))
    .map(parseVersions)
    .map(Production.Versions.make(yaml:))
    .get()
  }
}
