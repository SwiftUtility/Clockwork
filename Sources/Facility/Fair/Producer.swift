//import Foundation
//import Facility
//import FacilityPure
//public final class Producer {
//  let execute: Try.Reply<Execute>
//  let generate: Try.Reply<Generate>
//  let writeFile: Try.Reply<Files.WriteFile>
//  let parseFlow: Try.Reply<ParseYamlFile<Flow>>
//  let parseFlowStorage: Try.Reply<ParseYamlFile<Flow.Storage>>
//  let parseStdin: Try.Reply<Configuration.ParseStdin>
//  let persistAsset: Try.Reply<Configuration.PersistAsset>
//  let logMessage: Act.Reply<LogMessage>
//  let writeStdout: Act.Of<String>.Go
//  let jsonDecoder: JSONDecoder
//  public init(
//    execute: @escaping Try.Reply<Execute>,
//    generate: @escaping Try.Reply<Generate>,
//    writeFile: @escaping Try.Reply<Files.WriteFile>,
//    parseFlow: @escaping Try.Reply<ParseYamlFile<Flow>>,
//    parseFlowStorage: @escaping Try.Reply<ParseYamlFile<Flow.Storage>>,
//    parseStdin: @escaping Try.Reply<Configuration.ParseStdin>,
//    persistAsset: @escaping Try.Reply<Configuration.PersistAsset>,
//    logMessage: @escaping Act.Reply<LogMessage>,
//    writeStdout: @escaping Act.Of<String>.Go,
//    jsonDecoder: JSONDecoder
//  ) {
//    self.execute = execute
//    self.generate = generate
//    self.writeFile = writeFile
//    self.parseFlow = parseFlow
//    self.parseFlowStorage = parseFlowStorage
//    self.parseStdin = parseStdin
//    self.persistAsset = persistAsset
//    self.logMessage = logMessage
//    self.writeStdout = writeStdout
//    self.jsonDecoder = jsonDecoder
//  }
//  public func startHotfix(
//    cfg: Configuration,
//    product: String,
//    commit: String,
//    version: String
//  ) throws -> Bool {
//    let gitlab = try cfg.gitlab.get()
//    try perform(cfg: cfg, mutate: { storage in
//      let fixProduct: Flow.Product
//      let fixVersion: AlphaNumeric
//      let fixCommit: Git.Sha
//      if let commit = try commit.isEmpty.not.then(Git.Sha.make(value: commit)) {
//        fixCommit = commit
//        fixVersion = version.alphaNumeric
//        fixProduct = try storage.product(name: product)
//      } else {
//        let tag = try Git.Tag.make(job: gitlab.job)
//        guard let deploy = storage.deploys[tag]
//        else { throw Thrown("No deploy for \(tag.name)") }
//        fixVersion = deploy.version
//        let product = try storage.product(name: deploy.product)
//        fixProduct = product
//        fixCommit = try Git.Sha.make(value: Execute.parseText(
//          reply: execute(cfg.git.getSha(ref: .make(tag: tag)))
//        ))
//      }
//      let version = try generate(cfg.bumpVersion(
//        flow: storage.flow, product: fixProduct.name, version: fixVersion, kind: .hotfix
//      )).alphaNumeric
//      let release = try Flow.Release.make(
//        product: fixProduct,
//        version: version,
//        commit: fixCommit,
//        branch: generate(cfg.createReleaseBranchName(
//          flow: storage.flow, product: fixProduct.name, version: version, kind: .hotfix
//        ))
//      )
//      guard let min = fixProduct.prevVersions.min()
//      else { throw Thrown("No previous releases of \(fixProduct.name)") }
//      guard min < version
//      else { throw Thrown("Version \(version.value) must be greater than \(min.value)") }
//      guard fixProduct.nextVersion > version else { throw Thrown(
//        "Version \(version.value) must be less than \(fixProduct.nextVersion.value)"
//      )}
//      guard fixProduct.prevVersions.contains(version).not
//      else { throw Thrown("Version \(version.value) is known release") }
//      guard storage.releases[release.branch] == nil
//      else { throw Thrown("Release \(release.branch.name) already exists") }
//      storage.releases[release.branch] = release
//      guard try gitlab
//        .postBranches(name: release.branch.name, ref: fixCommit.value)
//        .map(execute)
//        .map(Execute.parseData(reply:))
//        .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
//        .get()
//        .protected
//      else { throw Thrown("Release \(release.branch.name) not protected") }
//      try Execute.checkStatus(reply: execute(cfg.git.fetchBranch(release.branch)))
//      cfg.reportReleaseBranchCreated(
//        release: release,
//        kind: .hotfix
//      )
//      try cfg.reportReleaseBranchSummary(release: release, notes: makeNotes(
//        cfg: cfg, storage: storage, release: release
//      ))
//      return cfg.createFlowStorageCommitMessage(
//        flow: storage.flow,
//        reason: .createReleaseBranch,
//        product: release.product,
//        version: release.version.value,
//        branch: release.branch.name
//      )
//    })
//    return true
//  }
//  public func createAccessoryBranch(
//    cfg: Configuration,
//    name: String,
//    commit: String
//  ) throws -> Bool {
//    let gitlab = try cfg.gitlab.get()
//    let commit = try commit.isEmpty.not
//      .then(Git.Sha.make(value: commit))
//      .flatMapNil(try? gitlab.parent.map(Git.Sha.make(job:)).get())
//      .get(.make(job: gitlab.job))
//    guard try resolveBranches(cfg: cfg).filter(\.protected)
//      .map(\.name)
//      .map(Git.Branch.make(name:))
//      .contains(where: { try Execute.parseSuccess(
//        reply: execute(cfg.git.check(child: .make(remote: $0), parent: .make(sha: commit)))
//      )})
//    else { throw Thrown("Not protected \(commit.value)") }
//    let accessory = try Flow.Accessory.make(branch: name)
//    try perform(cfg: cfg, mutate: { storage in
//      guard storage.accessories[accessory.branch] == nil else { throw Thrown(
//        "Branch \(accessory.branch.name) already present"
//      )}
//      storage.accessories[accessory.branch] = accessory
//      guard try gitlab
//        .postBranches(name: accessory.branch.name, ref: commit.value)
//        .map(execute)
//        .map(Execute.parseData(reply:))
//        .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
//        .get()
//        .protected
//      else { throw Thrown("\(accessory.branch.name) not protected") }
//      try Execute.checkStatus(reply: execute(cfg.git.fetchBranch(accessory.branch)))
//      cfg.reportAccessoryBranchCreated(commit: commit, accessory: accessory)
//      return cfg.createFlowStorageCommitMessage(
//        flow: storage.flow, reason: .createAccessoryBranch, branch: accessory.branch.name
//      )
//    })
//    return true
//  }
//  public func reserveBuild(cfg: Configuration, review: Bool, product: String) throws -> Bool {
//    let gitlab = try cfg.gitlab.get()
//    try perform(cfg: cfg, mutate: { storage in
//      let product = try storage.product(name: product)
//      var family = try storage.family(name: product.family)
//      let build: Flow.Build
//      let message: Generate
//      if review {
//        let parent = try gitlab.parent.get()
//        let merge = try gitlab.merge.get()
//        let sha = try Git.Sha.make(job: parent)
//        let branch = try Git.Branch.make(name: merge.targetBranch)
//        guard family.build(review: merge.iid, commit: sha) == nil else { return nil }
//        build = .make(number: family.nextBuild, review: merge.iid, commit: sha, branch: branch)
//        message = cfg.createFlowStorageCommitMessage(
//          flow: storage.flow,
//          reason: .reserveReviewBuild,
//          build: build.number.value,
//          review: merge.iid
//        )
//      } else {
//        let branch = try Git.Branch.make(job: gitlab.job)
//        let sha = try Git.Sha.make(job: gitlab.job)
//        guard family.build(commit: sha, branch: branch) == nil else { return nil }
//        build = .make(number: family.nextBuild, review: nil, commit: sha, branch: branch)
//        message = cfg.createFlowStorageCommitMessage(
//          flow: storage.flow,
//          reason: .reserveBranchBuild,
//          build: build.number.value,
//          branch: branch.name
//        )
//      }
//      family.builds[build.number] = build
//      try family.bump(build: generate(cfg.bumpBuild(flow: storage.flow, family: family)))
//      storage.families[family.name] = family
//      return message
//    })
//    return true
//  }
//  public func stageBuild(
//    cfg: Configuration,
//    build: String,
//    product: String
//  ) throws -> Bool {
//    let gitlab = try cfg.gitlab.get()
//    try perform(cfg: cfg, mutate: { storage in
//      let product = try storage.product(name: product)
//      let family = try storage.family(name: product.family)
//      guard let build = family.builds[build.alphaNumeric] else { throw Thrown(
//        "No build \(build) for \(product.name) reserved"
//      )}
//      let version = storage.releases[build.branch].map(\.version)
//        .flatMapNil(storage.accessories[build.branch]?.versions[product.name])
//        .get(product.nextVersion)
//      let stage = try Flow.Stage.make(
//        tag: generate(cfg.createTagName(
//          flow: storage.flow,
//          product: product.name,
//          version: version,
//          build: build.number,
//          kind: .stage
//        )),
//        product: product,
//        version: version,
//        build: build.number,
//        review: build.review,
//        branch: build.branch
//      )
//      guard storage.stages[stage.tag] == nil else { throw Thrown(
//        "Tag \(stage.tag.name) already exists"
//      )}
//      storage.stages[stage.tag] = stage
//      let annotation = try generate(cfg.createTagAnnotation(
//        flow: storage.flow,
//        product: stage.product,
//        version: stage.version,
//        build: stage.build,
//        kind: .stage
//      ))
//      guard try gitlab
//        .postTags(name: stage.tag.name, ref: build.commit.value, message: annotation)
//        .map(execute)
//        .map(Execute.parseData(reply:))
//        .reduce(Json.GitlabTag.self, jsonDecoder.decode(_:from:))
//        .get()
//        .protected
//      else { throw Thrown("Stage not protected \(stage.tag.name)") }
//      try Execute.checkStatus(reply: execute(cfg.git.fetchTag(stage.tag)))
//      cfg.reportStageTagCreated(commit: build.commit, stage: stage)
//      return cfg.createFlowStorageCommitMessage(
//        flow: storage.flow,
//        reason: .createStageTag,
//        product: stage.product,
//        version: stage.version.value,
//        build: stage.build.value,
//        review: stage.review,
//        branch: (stage.review != nil).then(stage.branch.name),
//        tag: stage.tag.name
//      )
//    })
//    return true
//  }
//  public func renderVersions(
//    cfg: Configuration,
//    product: String,
//    stdin: Configuration.ParseStdin,
//    args: [String]
//  ) throws -> Bool {
//    let stdin = try parseStdin(stdin)
//    let flow = try cfg.parseFlow.map(parseFlow).get()
//    let storage = try parseFlowStorage(cfg.parseFlowStorage(flow: flow))
//    var versions = storage.products.mapValues(\.nextVersion.value)
//    guard product.isEmpty.not else {
//      try writeStdout(generate(cfg.exportVersions(
//        flow: flow, stdin: stdin, args: args, versions: versions, build: nil, product: nil
//      )))
//      return true
//    }
//    let product = try storage.product(name: product)
//    let family = try storage.family(name: product.family)
//    let gitlab = try cfg.gitlab.get()
//    let sha = try Git.Sha.make(job: gitlab.job)
//    let build: String
//    if gitlab.job.tag {
//      let tag = try Git.Tag.make(job: gitlab.job)
//      if let deploy = storage.deploys[tag] {
//        guard deploy.product == product.name else { throw Thrown(
//          "Not \(product.name) deploy tag: \(tag.name)"
//        )}
//        build = deploy.build.value
//        versions[product.name] = deploy.version.value
//      } else if let stage = storage.stages[tag] {
//        guard stage.product == product.name else { throw Thrown(
//          "Not \(product.name) stage tag: \(tag.name)"
//        )}
//        build = stage.build.value
//        versions[product.name] = stage.version.value
//      } else {
//        throw Thrown("No deploy or stage for tag \(tag.name)")
//      }
//    } else if let review = try? gitlab.job.review.get() {
//      guard let present = family.build(review: review, commit: sha) else { throw Thrown(
//        "No builds reserved for review \(review) sha \(sha.value)"
//      )}
//      build = present.number.value
//      if let version = storage.version(product: product, build: present)?.value {
//        versions[product.name] = version
//      }
//    } else {
//      let branch = try Git.Branch.make(job: gitlab.job)
//      guard let present = family.build(commit: sha, branch: branch) else { throw Thrown(
//        "No builds reserved for branch \(branch.name) sha \(sha.value)"
//      )}
//      build = present.number.value
//      if let version = storage.version(product: product, build: present)?.value {
//        versions[product.name] = version
//      }
//    }
//    try writeStdout(generate(cfg.exportVersions(
//      flow: flow, stdin: stdin, args: args, versions: versions, build: build, product: product.name
//    )))
//    return true
//  }
//}
//extension Producer {
//  func perform(cfg: Configuration, mutate: Try.In<Flow.Storage>.Do<Generate?>) throws {
//    let flow = try cfg.parseFlow.map(parseFlow).get()
//    var storage = try parseFlowStorage(cfg.parseFlowStorage(flow: flow))
//    guard let message = try mutate(&storage).map(generate) else { return }
//    _ = try persistAsset(.init(
//      cfg: cfg,
//      asset: flow.storage,
//      content: storage.serialized,
//      message: message
//    ))
//  }
//  func resolveBranches(cfg: Configuration) throws -> [Json.GitlabBranch] {
//    var result: [Json.GitlabBranch] = []
//    var page = 1
//    let gitlab = try cfg.gitlab.get()
//    while true {
//      let branches = try gitlab
//        .getBranches(page: page, count: 100)
//        .map(execute)
//        .reduce([Json.GitlabBranch].self, jsonDecoder.decode(success:reply:))
//        .get()
//      result += branches
//      guard branches.count == 100 else { return result }
//      page += 1
//    }
//  }
//}
//
