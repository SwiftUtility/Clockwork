import Foundation
import Facility
import FacilityPure
public final class Producer {
  let execute: Try.Reply<Execute>
  let generate: Try.Reply<Generate>
  let writeFile: Try.Reply<Files.WriteFile>
  let parseProduction: Try.Reply<ParseYamlFile<Production>>
  let parseBuilds: Try.Reply<ParseYamlFile<[AlphaNumeric: Production.Build]>>
  let parseVersions: Try.Reply<ParseYamlFile<[String: Production.Version]>>
  let persistAsset: Try.Reply<Configuration.PersistAsset>
  let report: Act.Reply<Report>
  let readStdin: Try.Reply<Configuration.ReadStdin>
  let logMessage: Act.Reply<LogMessage>
  let writeStdout: Act.Of<String>.Go
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    generate: @escaping Try.Reply<Generate>,
    writeFile: @escaping Try.Reply<Files.WriteFile>,
    parseProduction: @escaping Try.Reply<ParseYamlFile<Production>>,
    parseBuilds: @escaping Try.Reply<ParseYamlFile<[AlphaNumeric: Production.Build]>>,
    parseVersions: @escaping Try.Reply<ParseYamlFile<[String: Production.Version]>>,
    persistAsset: @escaping Try.Reply<Configuration.PersistAsset>,
    report: @escaping Act.Reply<Report>,
    readStdin: @escaping Try.Reply<Configuration.ReadStdin>,
    logMessage: @escaping Act.Reply<LogMessage>,
    writeStdout: @escaping Act.Of<String>.Go,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.generate = generate
    self.writeFile = writeFile
    self.parseProduction = parseProduction
    self.parseBuilds = parseBuilds
    self.parseVersions = parseVersions
    self.persistAsset = persistAsset
    self.report = report
    self.readStdin = readStdin
    self.logMessage = logMessage
    self.writeStdout = writeStdout
    self.jsonDecoder = jsonDecoder
  }
  public func reportCustom(
    cfg: Configuration,
    event: String,
    stdin: Configuration.ReadStdin
  ) throws -> Bool {
    let stdin = try readStdin(stdin)
    let gitlab = try cfg.gitlab.get()
    let production = try cfg.parseProduction.map(parseProduction).get()
    let product: Production.Product
    let current: String
    if gitlab.job.tag {
      product = try production
        .productMatching(deploy: gitlab.job.pipeline.ref)
        .get { throw Thrown("Tag \(gitlab.job.pipeline.ref) matches no products") }
      current = try generate(product.parseTagVersion(
        cfg: cfg,
        ref: gitlab.job.pipeline.ref,
        deploy: true
      ))
    } else {
      product = try production
        .productMatching(release: gitlab.job.pipeline.ref)
        .get { throw Thrown("Branch \(gitlab.job.pipeline.ref) matches no products") }
      current = try generate(product.parseReleaseBranchVersion(
        cfg: cfg,
        ref: gitlab.job.pipeline.ref
      ))
    }
    let delivery = try parseVersions(cfg.parseVersions(production: production))[product.name]
      .get { throw Thrown("Versioning not configured for \(product)") }
      .deliveries[current.alphaNumeric]
      .get { throw Thrown("No \(product.name) \(current)") }
    report(product.reportReleaseCustom(
      cfg: cfg,
      event: event,
      delivery: delivery,
      ref: gitlab.job.pipeline.ref,
      sha: gitlab.job.pipeline.sha,
      stdin: stdin
    ))
    return true
  }
  public func changeVersion(
    cfg: Configuration,
    product: String,
    next: Bool,
    version: String
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let production = try cfg.parseProduction.map(parseProduction).get()
    let versions = try parseVersions(cfg.parseVersions(production: production))
    guard var update = versions[product]
    else { throw Thrown("Versioning not configured for \(product)") }
    let reason: Generate.CreateVersionsCommitMessage.Reason
    if next {
      try update.change(next: version)
      reason = .changeNext
    } else {
      guard gitlab.job.tag.not else { throw Thrown("Not branch job") }
      let branch = gitlab.job.pipeline.ref
      guard production.matchAccessoryBranch.isMet(branch)
      else { throw Thrown("Not accessory branch \(branch)") }
      update.accessories[branch] = version.alphaNumeric
      reason = .changeAccessory
    }
    return try persist(
      cfg: cfg,
      production: production,
      versions: versions,
      update: update,
      product: update.product,
      version: version,
      reason: reason
    )
  }
  public func deleteStageTag(cfg: Configuration) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let production = try cfg.parseProduction.map(parseProduction).get()
    guard gitlab.job.tag else { throw Thrown("Not on tag") }
    let name = gitlab.job.pipeline.ref
    guard let product = try production.productMatching(stage: name)
    else { throw Thrown("Not on stage tag") }
    try gitlab.deleteTag(name: name)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try report(product.reportStageTagDeleted(
      cfg: cfg,
      ref: name,
      sha: gitlab.job.pipeline.sha,
      version: generate(product.parseTagBuild(cfg: cfg, ref: name, deploy: false)),
      build: generate(product.parseTagBuild(cfg: cfg, ref: name, deploy: false))
    ))
    return true
  }
  public func deleteBranch(cfg: Configuration, revoke: Bool?) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let production = try cfg.parseProduction.map(parseProduction).get()
    var versions = try parseVersions(cfg.parseVersions(production: production))
    guard gitlab.job.tag.not else { throw Thrown("Not on branch") }
    let branch = try Git.Branch.init(name: gitlab.job.pipeline.ref)
    let sha = try Git.Sha.make(job: gitlab.job)
    guard try Execute.parseSuccess(reply: execute(cfg.git.check(
      child: .make(sha: sha),
      parent: .make(remote: branch)
    ))) else { throw Thrown("Not last commit pipeline") }
    let defaultBranch = try gitlab.getProject
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabProject.self, jsonDecoder.decode(_:from:))
      .get()
      .defaultBranch
    guard try Execute.parseSuccess(reply: execute(cfg.git.check(
      child: .make(remote: .init(name: defaultBranch)),
      parent: .make(sha: sha)
    ))) else { throw Thrown("Branch \(branch) not integrated into \(defaultBranch)") }
    if let revoke = revoke {
      let product = try production
        .productMatching(release: branch.name)
        .get { throw Thrown("Branch \(branch) matches no products") }
      let current = try generate(product.parseReleaseBranchVersion(cfg: cfg, ref: branch.name))
      if let delivery = versions[product.name]?.deliveries[current.alphaNumeric] {
        if revoke {
          try versions[product.name]?.revoke(version: current, sha: sha)
          _ = try persist(
            cfg: cfg,
            production: production,
            versions: versions,
            update: nil,
            product: product.name,
            version: current,
            reason: .revokeRelease
          )
        }
        try gitlab.deleteBranch(name: branch.name)
          .map(execute)
          .map(Execute.checkStatus(reply:))
          .get()
        report(product.reportReleaseBranchDeleted(
          cfg: cfg, delivery: delivery, ref: branch.name, sha: sha.value, revoke: revoke
        ))
      }
    } else {
      guard production.matchAccessoryBranch.isMet(branch.name)
      else { throw Thrown("Not accessory branch \(branch.name)") }
      versions.keys.forEach({ versions[$0]?.accessories[branch.name] = nil })
      try gitlab.deleteBranch(name: branch.name)
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
      _ = try persist(
        cfg: cfg,
        production: production,
        versions: versions,
        update: nil,
        product: nil,
        version: nil,
        reason: .deleteAccessory
      )
      report(cfg.reportAccessoryBranchDeleted(ref: branch.name))
    }
    return true
  }
  public func forwardBranch(cfg: Configuration, name: String) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    guard gitlab.job.tag.not else { throw Thrown("Not on branch") }
    let sha = try Git.Sha.make(job: gitlab.job)
    let forward = try gitlab.getBranch(name: name)
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
      .get()
    guard forward.protected else { throw Thrown("Branch \(name) not protected") }
    guard forward.default.not else { throw Thrown("Branch \(name) is default") }
    guard try Execute.parseSuccess(reply: execute(cfg.git.check(
      child: .make(sha: sha),
      parent: .make(remote: .init(name: name))
    ))) else { throw Thrown("Not fast forward \(sha.value)") }
    try gitlab.deleteBranch(name: name)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try gitlab.postBranches(name: name, ref: sha.value)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func createDeployTag(cfg: Configuration) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let production = try cfg.parseProduction.map(parseProduction).get()
    guard !gitlab.job.tag else { throw Thrown("Not on branch") }
    let branch = gitlab.job.pipeline.ref
    let product = try production
      .productMatching(release: branch)
      .get { throw Thrown("Branch \(branch) matches no products") }
    let current = try generate(product.parseReleaseBranchVersion(cfg: cfg, ref: branch))
    let sha = try Git.Sha.make(job: gitlab.job)
    let versions = try parseVersions(cfg.parseVersions(production: production))
    guard var version = versions[product.name]
    else { throw Thrown("Versioning not configured for \(product)") }
    let delivery = try version.deploy(version: current, sha: sha)
    let builds = try parseBuilds(cfg.parseBuilds(production: production))
    guard let build = try builds.keys.max().map(\.value)
      .reduce(cfg, production.bumpBuildNumber(cfg:build:))
      .map(generate)
    else { throw Thrown("No builds in asset") }
    let tag = try generate(product.createTagName(
      cfg: cfg,
      version: current,
      build: build,
      deploy: true
    ))
    let annotation = try generate(product.createTagAnnotation(
      cfg: cfg,
      version: current,
      build: build,
      deploy: true
    ))
    try persist(cfg: cfg, production: production, builds: builds, update: .tag(.make(
      build: build.alphaNumeric,
      sha: sha.value,
      tag: tag
    )))
    _ = try persist(
      cfg: cfg,
      production: production,
      versions: versions,
      update: version,
      product: version.product,
      version: current,
      reason: .deploy
    )
    try gitlab
      .postTags(name: tag, ref: gitlab.job.pipeline.sha, message: annotation)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try report(product.reportDeployTagCreated(
      cfg: cfg,
      delivery: delivery,
      ref: tag,
      sha: sha.value,
      build: build,
      notes: makeNotes(cfg: cfg, production: production, sha: sha, delivery: delivery)
    ))
    return true
  }
  public func reserveReviewBuild(cfg: Configuration) throws -> Bool {
    let production = try cfg.parseProduction.map(parseProduction).get()
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.env.parent.get()
    let job = try gitlab.getJob(id: parent.job)
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    let review = try job.review
      .flatMap(gitlab.getMrState(review:))
      .map(execute)
      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
      .get()
    let builds = try parseBuilds(cfg.parseBuilds(production: production))
    guard !builds.values.contains(where: review.matches(build:)) else {
      logMessage(.init(message: "Build already exists"))
      return true
    }
    let build = try job.makeBuild(review: review, build: generate(production.bumpBuildNumber(
      cfg: cfg,
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
    let gitlab = try cfg.gitlab.get()
    let production = try cfg.parseProduction.map(parseProduction).get()
    let builds = try parseBuilds(cfg.parseBuilds(production: production))
    guard gitlab.job.tag.not else { throw Thrown("Not on branch") }
    guard builds.values.contains(where: gitlab.matches(build:)).not else {
      logMessage(.init(message: "Build already exists"))
      return true
    }
    try persist(
      cfg: cfg,
      production: production,
      builds: builds,
      update: try builds.keys.max().map(\.value)
        .reduce(cfg, production.bumpBuildNumber(cfg:build:))
        .map(generate)
        .map(gitlab.job.makeBuild(build:))
        .get { throw Thrown("No builds in asset") }
    )
    return true
  }
  public func createReleaseBranch(cfg: Configuration, product: String) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let production = try cfg.parseProduction.map(parseProduction).get()
    guard let product = production.products[product]
    else { throw Thrown("Produnc \(product) not configured") }
    let versions = try parseVersions(cfg.parseVersions(production: production))
    guard var version = versions[product.name]
    else { throw Thrown("Versioning not configured for \(product)") }
    let current = version.next.value
    let branch = try Git.Branch(name: generate(product.createReleaseBranchName(
      cfg: cfg,
      version: current,
      hotfix: false
    )))
    let bump = try generate(product.bumpReleaseVersion(
      cfg: cfg,
      version: current,
      hotfix: false
    ))
    let sha = try Git.Sha.make(job: gitlab.job)
    try version.check(bump: bump)
    guard try gitlab
      .postBranches(name: branch.name, ref: gitlab.job.pipeline.sha)
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
      .get()
      .protected
    else { throw Thrown("Release \(branch) not protected") }
    report(product.reportReleaseBranchCreated(
      cfg: cfg,
      ref: branch.name,
      version: current,
      hotfix: false
    ))
    let delivery = version.release(bump: bump, start: sha)
    _ = try persist(
      cfg: cfg,
      production: production,
      versions: versions,
      update: version,
      product: version.product,
      version: current,
      reason: .release
    )
    try report(product.reportReleaseBranchSummary(
      cfg: cfg,
      delivery: delivery,
      ref: branch.name,
      sha: sha.value,
      notes: makeNotes(cfg: cfg, production: production, sha: sha, delivery: delivery)
    ))
    return true
  }
  public func createHotfixBranch(cfg: Configuration) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let production = try cfg.parseProduction.map(parseProduction).get()
    guard gitlab.job.tag else { throw Thrown("Not on tag") }
    let product = try production
      .productMatching(deploy: gitlab.job.pipeline.ref)
      .get { throw Thrown("Tag \(gitlab.job.pipeline.ref) matches no products") }
    let versions = try parseVersions(cfg.parseVersions(production: production))
    guard var version = versions[product.name]
    else { throw Thrown("Versioning not configured for \(product.name)") }
    let sha = try Git.Sha.make(job: gitlab.job)
    let current = try generate(product.parseTagVersion(
      cfg: cfg,
      ref: gitlab.job.pipeline.ref,
      deploy: true
    ))
    let hotfix = try generate(product.bumpReleaseVersion(
      cfg: cfg,
      version: current,
      hotfix: true
    ))
    let branch = try generate(product.createReleaseBranchName(
      cfg: cfg,
      version: hotfix,
      hotfix: true
    ))
    try version.check(hotfix: hotfix, of: current)
    guard try gitlab
      .postBranches(name: branch, ref: gitlab.job.pipeline.sha)
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
      .get()
      .protected
    else { throw Thrown("Hotfix \(branch) not protected") }
    report(product.reportReleaseBranchCreated(
      cfg: cfg,
      ref: branch,
      version: hotfix,
      hotfix: true
    ))
    let delivery = version.hotfix(version: hotfix, start: sha)
    _ = try persist(
      cfg: cfg,
      production: production,
      versions: versions,
      update: version,
      product: version.product,
      version: current,
      reason: .hotfix
    )
    try report(product.reportReleaseBranchSummary(
      cfg: cfg,
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
    let gitlab = try cfg.gitlab.get()
    let criteria = try cfg.parseProduction.map(parseProduction).get().matchAccessoryBranch
    guard criteria.isMet(name) else { throw Thrown("\(name) does not meat accessory criteria") }
    guard try gitlab
      .postBranches(name: name, ref: gitlab.job.pipeline.sha)
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
      .get()
      .protected
    else { throw Thrown("\(name) not protected") }
    report(cfg.reportAccessoryBranchCreated(ref: name))
    return true
  }
  public func stageBuild(cfg: Configuration, product: String, build: String) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let production = try cfg.parseProduction.map(parseProduction).get()
    guard let product = production.products[product]
    else { throw Thrown("Production not configured for \(product)") }
    guard let version = try parseVersions(cfg.parseVersions(production: production))[product.name]
    else { throw Thrown("No versions for \(product)") }
    guard let build = try parseBuilds(cfg.parseBuilds(production: production))[build.alphaNumeric]
    else { throw Thrown("No build \(build) reserved") }
    guard let branch = build.target.flatMapNil(build.branch)
    else { throw Thrown("Can not stage tag builds") }
    var current: String = version.next.value
    if product.matchReleaseBranch.isMet(branch) {
      current = try generate(product.parseReleaseBranchVersion(cfg: cfg, ref: branch))
    } else if production.matchAccessoryBranch.isMet(branch) {
      current = version.accessories[branch]?.value ?? current
    }
    let tag = try generate(product.createTagName(
      cfg: cfg,
      version: current,
      build: build.build.value,
      deploy: false
    ))
    let annotation = try generate(product.createTagAnnotation(
      cfg: cfg,
      version: current,
      build: build.build.value,
      deploy: false
    ))
    try gitlab
      .postTags(name: tag, ref: build.sha, message: annotation)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    report(product.reportStageTagCreated(
      cfg: cfg,
      ref: tag,
      sha: build.sha,
      version: current,
      build: build.build.value
    ))
    return true
  }
  public func renderBuild(cfg: Configuration) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let production = try cfg.parseProduction.map(parseProduction).get()
    let name = gitlab.job.pipeline.ref
    let build: String
    let versions = try parseVersions(cfg.parseVersions(production: production))
    var current = versions.mapValues(\.next.value)
    let kind: Generate.ExportBuildContext.Kind
    if gitlab.job.tag {
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
      build = try generate(product.parseTagBuild(
        cfg: cfg,
        ref: name,
        deploy: deploy
      ))
      current[product.name] = try generate(product.parseTagVersion(
        cfg: cfg,
        ref: name,
        deploy: deploy
      ))
      kind = deploy.then(.deploy).get(.stage)
    } else {
      guard let resolved = try parseBuilds(cfg.parseBuilds(production: production))
        .values
        .first(where: gitlab.job.matches(build:))
      else {
        logMessage(.init(message: "No build number reserved"))
        return false
      }
      kind = (resolved.target != nil).then(.review).get(.branch)
      build = resolved.build.value
      let branch = resolved.target.get(name)
      if let product = try production.productMatching(release: branch) {
        current[product.name] = try generate(product.parseReleaseBranchVersion(
          cfg: cfg,
          ref: branch
        ))
      } else if production.matchAccessoryBranch.isMet(branch) {
        for product in production.products.keys {
          current[product] = versions[product]?.accessories[branch]?.value ?? current[product]
        }
      }
    }
    try writeStdout(generate(production.exportBuildContext(
      cfg: cfg,
      versions: current,
      build: build,
      kind: kind
    )))
    return true
  }
  public func renderNextVersions(cfg: Configuration) throws -> Bool {
    let production = try cfg.parseProduction.map(parseProduction).get()
    try writeStdout(generate(production.exportCurrentVersions(
      cfg: cfg,
      versions: parseVersions(cfg.parseVersions(production: production)).mapValues(\.next.value)
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
      message: generate(production.createBuildCommitMessage(cfg: cfg, build: update))
    ))
  }
  func persist(
    cfg: Configuration,
    production: Production,
    versions: [String: Production.Version],
    update: Production.Version?,
    product: String?,
    version: String?,
    reason: Generate.CreateVersionsCommitMessage.Reason
  ) throws -> Bool {
    var versions = versions
    if let update = update { versions[update.product] = update }
    return try persistAsset(.init(
      cfg: cfg,
      asset: production.versions,
      content: production.serialize(versions: versions),
      message: generate(production.createVersionsCommitMessage(
        cfg: cfg,
        product: product,
        version: version,
        reason: reason
      ))
    ))
  }
}
