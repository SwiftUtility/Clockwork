import Foundation
import Facility
import FacilityPure
public final class Producer {
  let execute: Try.Reply<Execute>
  let generate: Try.Reply<Generate>
  let writeFile: Try.Reply<Files.WriteFile>
  let parseFlow: Try.Reply<ParseYamlFile<Flow>>
  let parseFlowBuilds: Try.Reply<ParseYamlFile<Flow.Builds.Storage>>
  let parseFlowVersions: Try.Reply<ParseYamlFile<Flow.Versions.Storage>>
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
    parseFlow: @escaping Try.Reply<ParseYamlFile<Flow>>,
    parseFlowBuilds: @escaping Try.Reply<ParseYamlFile<Flow.Builds.Storage>>,
    parseFlowVersions: @escaping Try.Reply<ParseYamlFile<Flow.Versions.Storage>>,
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
    self.parseFlow = parseFlow
    self.parseFlowBuilds = parseFlowBuilds
    self.parseFlowVersions = parseFlowVersions
    self.persistAsset = persistAsset
    self.report = report
    self.readStdin = readStdin
    self.logMessage = logMessage
    self.writeStdout = writeStdout
    self.jsonDecoder = jsonDecoder
  }
  public func signal(
    cfg: Configuration,
    event: String,
    stdin: Configuration.ReadStdin,
    args: [String]
  ) throws -> Bool {
//    let stdin = try readStdin(stdin)
//    let gitlab = try cfg.gitlab.get()
//    let flow = try cfg.parseFlow.map(parseFlow).get()
//    let storage = try parseFlowStorage(cfg.parseFlowStorage(flow: flow))
//    let current: String
//    if gitlab.job.tag {
//      product = try flow
//        .productMatching(deploy: gitlab.job.pipeline.ref)
//        .get { throw Thrown("Tag \(gitlab.job.pipeline.ref) matches no products") }
//      current = try generate(product.parseTagVersion(
//        cfg: cfg,
//        ref: gitlab.job.pipeline.ref,
//        deploy: true
//      ))
//    } else {
//      product = try flow
//        .productMatching(release: gitlab.job.pipeline.ref)
//        .get { throw Thrown("Branch \(gitlab.job.pipeline.ref) matches no products") }
//      current = try generate(product.parseReleaseBranchVersion(
//        cfg: cfg,
//        ref: gitlab.job.pipeline.ref
//      ))
//    }
//    let delivery = try parseVersions(cfg.parseVersions(flow: flow))[product.name]
//      .get { throw Thrown("Versioning not configured for \(product)") }
//      .deliveries[current.alphaNumeric]
//      .get { throw Thrown("No \(product.name) \(current)") }
//    report(cfg.reportReleaseCustom(
//      product: product,
//      event: event,
//      delivery: delivery,
//      ref: gitlab.job.pipeline.ref,
//      sha: gitlab.job.pipeline.sha,
//      stdin: stdin
//    ))
//    return true
    #warning("tbd")
    return false
  }
  public func changeVersion(
    cfg: Configuration,
    product: String,
    next: Bool,
    version: String
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let flow = try cfg.parseFlow.map(parseFlow).get()
    var versions = try parseFlowVersions(cfg.parseFlowVersions(flow: flow))
    let reason: Generate.CreateFlowVersionsCommitMessage.Reason
    if next {
      try versions.change(product: product, next: version)
      reason = .changeNext
    } else {
      guard gitlab.job.tag.not else { throw Thrown("Not branch job") }
      try versions.change(accessory: gitlab.job.pipeline.ref, product: product, version: version)
      reason = .changeAccessory
    }
    return try persistAsset(.init(
      cfg: cfg,
      asset: flow.versions.storage,
      content: versions.serialized(versions: flow.versions),
      message: generate(cfg.createFlowVersionsCommitMessage(
        flow: flow,
        product: product,
        version: version,
        reason: reason
      ))
    ))
  }
  public func deleteStageTag(cfg: Configuration) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let flow = try cfg.parseFlow.map(parseFlow).get()
    guard gitlab.job.tag else { throw Thrown("Not on tag") }
    let name = gitlab.job.pipeline.ref
    var versions = try parseFlowVersions(cfg.parseFlowVersions(flow: flow))
    let stage = try versions.delete(stage: .make(name: name))
    try gitlab.deleteTag(name: name)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    _ = try persistAsset(.init(
      cfg: cfg,
      asset: flow.versions.storage,
      content: versions.serialized(versions: flow.versions),
      message: generate(cfg.createFlowVersionsCommitMessage(
        flow: flow,
        product: stage.product,
        version: stage.version.value,
        reason: .deleteAccessory
      ))
    ))
    report(cfg.reportStageTagDeleted(stage: stage))
    return true
  }
  public func deleteBranch(cfg: Configuration, release: Bool) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let project = try gitlab.project.get()
    let flow = try cfg.parseFlow.map(parseFlow).get()
    var versions = try parseFlowVersions(cfg.parseFlowVersions(flow: flow))
    let branch = try Git.Branch.make(job: gitlab.job)
    let sha = try Git.Sha.make(job: gitlab.job)
    guard try Execute.parseSuccess(reply: execute(cfg.git.check(
      child: .make(sha: sha),
      parent: .make(remote: branch)
    ))) else { throw Thrown("Not last commit pipeline") }
    guard try Execute.parseSuccess(reply: execute(cfg.git.check(
      child: .make(remote: .make(name: project.defaultBranch)),
      parent: .make(sha: sha)
    ))) else { throw Thrown("Branch \(branch.name) not merged into \(project.defaultBranch)") }
    if release {
      guard let release = versions.find(release: branch)
      else { throw Thrown("No release for branch \(branch.name)") }
      try gitlab.deleteBranch(name: branch.name)
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
      report(cfg.reportReleaseBranchDeleted(release: release))
    } else {
      let accessory = try versions.delete(accessory: branch)
      _ = try persistAsset(.init(
        cfg: cfg,
        asset: flow.versions.storage,
        content: versions.serialized(versions: flow.versions),
        message: generate(cfg.createFlowVersionsCommitMessage(
          flow: flow,
          ref: accessory.branch.name,
          reason: .deleteAccessory
        ))
      ))
      try gitlab.deleteBranch(name: branch.name)
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
      report(cfg.reportAccessoryBranchDeleted(ref: branch.name))
    }
    return true
  }
  public func forwardBranch(cfg: Configuration, name: String) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
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
      parent: .make(remote: .make(name: name))
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
    let branch = try Git.Branch.make(job: gitlab.job)
    let sha = try Git.Sha.make(job: gitlab.job)
    let flow = try cfg.parseFlow.map(parseFlow).get()
    var versions = try parseFlowVersions(cfg.parseFlowVersions(flow: flow))
    guard var release = versions.find(release: branch)
    else { throw Thrown("No release branch \(branch.name)") }
    let builds = try flow.builds.map(cfg.parseFlowBuilds(builds:)).map(parseFlowBuilds)
    let tag = try Git.Tag.make(name: generate(cfg.createTagName(
      flow: flow,
      product: release.product,
      version: release.version.value,
      build: builds?.next.value,
      deploy: true
    )))
    let annotation = try generate(cfg.createTagAnnotation(
      flow: flow,
      product: release.product,
      version: release.version.value,
      build: builds?.next.value,
      deploy: true
    ))
    release = try versions.deploy(
      product: release.product,
      version: release.version,
      tag: tag
    )
    var build: Flow.Build? = nil
    if var builds = builds, let flowBuilds = flow.builds {
      let reserved = try builds.reserve(tag: tag, sha: sha, bump: generate(
        cfg.bumpBuildNumber(builds: flowBuilds, build: builds.next.value)
      ))
      build = reserved
      _ = try persistAsset(.init(
        cfg: cfg,
        asset: flowBuilds.storage,
        content: builds.serialized(builds: flowBuilds),
        message: generate(cfg.createFlowBuildsCommitMessage(builds: flowBuilds, build: reserved))
      ))
    }
    _ = try persistAsset(.init(
      cfg: cfg,
      asset: flow.versions.storage,
      content: versions.serialized(versions: flow.versions),
      message: generate(cfg.createFlowVersionsCommitMessage(
        flow: flow,
        product: release.product,
        version: release.version.value,
        ref: tag.name,
        reason: .deploy
      ))
    ))
    guard try gitlab
      .postTags(name: tag.name, ref: gitlab.job.pipeline.sha, message: annotation)
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabTag.self, jsonDecoder.decode(_:from:))
      .get()
      .protected
    else { throw Thrown("Stage not protected \(tag.name)") }
    try report(cfg.reportDeployTagCreated(
      release: release,
      build: build,
      notes: makeNotes(cfg: cfg, flow: flow, release: release, deploy: sha)
    ))
    return true
  }
  public func reserveBuild(cfg: Configuration, review: Bool) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let flow = try cfg.parseFlow.map(parseFlow).get()
    guard let flowBuilds = flow.builds else { throw Thrown("Builds not configured") }
    var builds = try parseFlowBuilds(cfg.parseFlowBuilds(builds: flowBuilds))
    let build: Flow.Build
    if review {
      let parent = try gitlab.parent.get()
      let merge = try gitlab.merge.get()
      if let build = builds.recent.first(where: parent.matches(build:)) {
        guard build.target?.name != merge.targetBranch else {
          logMessage(.init(message: "Build already exists"))
          return true
        }
      }
      build = try builds.reserve(merge: merge, job: parent, bump: generate(cfg.bumpBuildNumber(
        builds: flowBuilds,
        build: builds.next.value
      )))
    } else {
      let branch = try Git.Branch.make(job: gitlab.job)
      let flow = try cfg.parseFlow.map(parseFlow).get()
      guard builds.recent.contains(where: gitlab.job.matches(build:)).not else {
        logMessage(.init(message: "Build already exists"))
        return true
      }
      build = try builds.reserve(
        branch: branch,
        sha: .make(job: gitlab.job),
        bump: generate(cfg.bumpBuildNumber(builds: flowBuilds, build: builds.next.value))
      )
    }
    _ = try persistAsset(.init(
      cfg: cfg,
      asset: flowBuilds.storage,
      content: builds.serialized(builds: flowBuilds),
      message: generate(cfg.createFlowBuildsCommitMessage(builds: flowBuilds, build: build))
    ))
    return true
  }
  public func createReleaseBranch(cfg: Configuration, product: String) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let sha = try Git.Sha.make(job: gitlab.job)
    let flow = try cfg.parseFlow.map(parseFlow).get()
    var versions = try parseFlowVersions(cfg.parseFlowVersions(flow: flow))
    guard let product = versions.products[product]
    else { throw Thrown("No product \(product)") }
    let bump = try generate(cfg.bumpReleaseVersion(
      flow: flow,
      product: product.name,
      version: product.next.value,
      hotfix: false
    ))
    let branch = try Git.Branch.make(name: generate(cfg.createReleaseBranchName(
      flow: flow,
      product: product.name,
      version: product.next.value,
      hotfix: false
    )))
    let release = try versions.release(
      product: product.name,
      branch: branch,
      sha: sha,
      hotfix: false,
      bump: bump
    )
    guard try gitlab
      .postBranches(name: branch.name, ref: gitlab.job.pipeline.sha)
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
      .get()
      .protected
    else { throw Thrown("Release \(branch.name) not protected") }
    _ = try persistAsset(.init(
      cfg: cfg,
      asset: flow.versions.storage,
      content: versions.serialized(versions: flow.versions),
      message: generate(cfg.createFlowVersionsCommitMessage(
        flow: flow,
        product: release.product,
        version: release.version.value,
        ref: release.branch.name,
        reason: .release
      ))
    ))
    report(cfg.reportReleaseBranchCreated(
      release: release,
      hotfix: false
    ))
    try report(cfg.reportReleaseBranchSummary(
      release: release,
      notes: makeNotes(cfg: cfg, flow: flow, release: release, deploy: release.start)
    ))
    return true
  }
  public func createHotfixBranch(cfg: Configuration) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let flow = try cfg.parseFlow.map(parseFlow).get()
    let tag = try Git.Tag.make(job: gitlab.job)
    let sha = try Git.Sha.make(job: gitlab.job)
    var versions = try parseFlowVersions(cfg.parseFlowVersions(flow: flow))
    guard var release = versions.find(deploy: tag)
    else { throw Thrown("No deploy \(tag.name)") }
    let bump = try generate(cfg.bumpReleaseVersion(
      flow: flow,
      product: release.product,
      version: release.version.value,
      hotfix: true
    ))
    let branch = try Git.Branch.make(name: generate(cfg.createReleaseBranchName(
      flow: flow,
      product: release.product,
      version: bump,
      hotfix: true
    )))
    release = try versions.release(
      product: release.product,
      branch: branch,
      sha: sha,
      hotfix: true,
      bump: bump
    )
    guard try gitlab
      .postBranches(name: branch.name, ref: gitlab.job.pipeline.sha)
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
      .get()
      .protected
    else { throw Thrown("Release \(branch.name) not protected") }
    _ = try persistAsset(.init(
      cfg: cfg,
      asset: flow.versions.storage,
      content: versions.serialized(versions: flow.versions),
      message: generate(cfg.createFlowVersionsCommitMessage(
        flow: flow,
        product: release.product,
        version: release.version.value,
        ref: release.branch.name,
        reason: .hotfix
      ))
    ))
    report(cfg.reportReleaseBranchCreated(
      release: release,
      hotfix: true
    ))
    try report(cfg.reportReleaseBranchSummary(
      release: release,
      notes: makeNotes(cfg: cfg, flow: flow, release: release, deploy: release.start)
    ))
    return true
  }
  public func createAccessoryBranch(
    cfg: Configuration,
    name: String
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let flow = try cfg.parseFlow.map(parseFlow).get()
    var versions = try parseFlowVersions(cfg.parseFlowVersions(flow: flow))
    _ = try versions.create(accessory: name)
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
    let flow = try cfg.parseFlow.map(parseFlow).get()
    var versions = try parseFlowVersions(cfg.parseFlowVersions(flow: flow))
    guard let product = versions.products[product]
    else { throw Thrown("No product \(product)") }
    guard let flowBuilds = flow.builds
    else { throw Thrown("Builds not configured") }
    let builds = try parseFlowBuilds(cfg.parseFlowBuilds(builds: flowBuilds))
    guard let build = builds.reserved[build.alphaNumeric]
    else { throw Thrown("No build \(build)") }
    if let tag = build.tag, let release = versions.find(deploy: tag) {
      guard release.product != product.name
      else { throw Thrown("Can not stage deploy of same product \(product)") }
    }
    let version = build.branch
      .flatMapNil(build.target)
      .flatMap(versions.find(release:))
      .filter(isIncluded: { $0.product == product.name })
      .map(\.version)
      .get(product.next)
    let tag = try Git.Tag.make(name: generate(cfg.createTagName(
      flow: flow,
      product: product.name,
      version: version.value,
      build: build.number.value,
      deploy: false
    )))
    let annotation = try generate(cfg.createTagAnnotation(
      flow: flow,
      product: product.name,
      version: version.value,
      build: build.number.value,
      deploy: false
    ))
    let stage = try versions.stage(product: product.name, version: version, build: build, tag: tag)
    guard try gitlab
      .postTags(name: tag.name, ref: build.commit.value, message: annotation)
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabTag.self, jsonDecoder.decode(_:from:))
      .get()
      .protected
    else { throw Thrown("Stage not protected \(tag.name)") }
    report(cfg.reportStageTagCreated(stage: stage))
    return true
  }
  public func renderVersions(cfg: Configuration, build: Bool, args: [String]) throws -> Bool {
    let flow = try cfg.parseFlow.map(parseFlow).get()
    let versions = try parseFlowVersions(cfg.parseFlowVersions(flow: flow))
    guard build else {
      try writeStdout(generate(cfg.exportVersions(
        flow: flow,
        args: args,
        versions: versions.products.mapValues(\.next.value),
        build: nil,
        kind: nil
      )))
      return true
    }
    let gitlab = try cfg.gitlab.get()
    if gitlab.job.tag, let stage = try versions.find(stage: .make(job: gitlab.job)) {
      try writeStdout(generate(cfg.exportVersions(
        flow: flow,
        args: args,
        versions: versions.versions(stage: stage),
        build: stage.build.value,
        kind: .stage
      )))
      return true
    }
    guard let flowBuilds = flow.builds
    else { throw Thrown("Builds not configured") }
    let builds = try parseFlowBuilds(cfg.parseFlowBuilds(builds: flowBuilds))
    guard let build = builds.recent.first(where: gitlab.job.matches(build:)) else {
      logMessage(.init(message: "No build reserved for \(gitlab.job.webUrl)"))
      return false
    }
    try writeStdout(generate(cfg.exportVersions(
      flow: flow,
      args: args,
      versions: versions.versions(build: build),
      build: build.number.value,
      kind: build.kind
    )))
    return true
  }
  func makeNotes(
    cfg: Configuration,
    flow: Flow,
    release: Flow.Product.Release,
    deploy: Git.Sha
  ) throws -> Flow.ReleaseNotes {
    let previous = try Id(release.previous.map(Git.Ref.make(tag:)))
      .map(cfg.git.excludeParents(shas:))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .map(Git.Sha.make(value:))
      .map(Git.Ref.make(sha:))
    guard previous.isEmpty.not else { return .make(uniq: [], lack: []) }
    #warning("tbd remove cherry picks")
    return try Flow.ReleaseNotes.make(
      uniq: Execute
        .parseLines(reply: execute(cfg.git.listCommits(
          in: [.make(sha: deploy)],
          notIn: previous,
          ignoreMissing: true
        )))
        .compactMap({ sha in try flow.makeNote(sha: sha, msg: Execute.parseText(
          reply: execute(cfg.git.getCommitMessage(ref: .make(sha: .make(value: sha))))
        ))}),
      lack: Execute
        .parseLines(reply: execute(cfg.git.listCommits(
          in: previous,
          notIn: [.make(sha: deploy)],
          ignoreMissing: true
        )))
        .compactMap({ sha in try flow.makeNote(sha: sha, msg: Execute.parseText(
          reply: execute(cfg.git.getCommitMessage(ref: .make(sha: .make(value: sha))))
        ))})
    )
  }
}
