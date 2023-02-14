import Foundation
import Facility
import FacilityPure
public final class Producer {
  let execute: Try.Reply<Execute>
  let generate: Try.Reply<Generate>
  let writeFile: Try.Reply<Files.WriteFile>
  let parseFlow: Try.Reply<ParseYamlFile<Flow>>
  let parseFlowStorage: Try.Reply<ParseYamlFile<Flow.Storage>>
  let parseStdin: Try.Reply<Configuration.ParseStdin>
  let persistAsset: Try.Reply<Configuration.PersistAsset>
  let logMessage: Act.Reply<LogMessage>
  let writeStdout: Act.Of<String>.Go
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    generate: @escaping Try.Reply<Generate>,
    writeFile: @escaping Try.Reply<Files.WriteFile>,
    parseFlow: @escaping Try.Reply<ParseYamlFile<Flow>>,
    parseFlowStorage: @escaping Try.Reply<ParseYamlFile<Flow.Storage>>,
    parseStdin: @escaping Try.Reply<Configuration.ParseStdin>,
    persistAsset: @escaping Try.Reply<Configuration.PersistAsset>,
    logMessage: @escaping Act.Reply<LogMessage>,
    writeStdout: @escaping Act.Of<String>.Go,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.generate = generate
    self.writeFile = writeFile
    self.parseFlow = parseFlow
    self.parseFlowStorage = parseFlowStorage
    self.parseStdin = parseStdin
    self.persistAsset = persistAsset
    self.logMessage = logMessage
    self.writeStdout = writeStdout
    self.jsonDecoder = jsonDecoder
  }
  public func changeAccessoryVersion(
    cfg: Configuration,
    product: String,
    branch: String,
    version: String
  ) throws -> Bool {
    let branch = try branch.isEmpty.not
      .then(Git.Branch.make(name: branch))
      .get(.make(job: cfg.gitlab.map(\.job).get()))
    try perform(cfg: cfg, mutate: { storage in
      try storage.change(product: product, nextVersion: version)
      return cfg.createFlowStorageCommitMessage(
        flow: storage.flow,
        reason: .changeAccessoryVersion,
        product: product,
        version: version,
        branch: branch.name
      )
    })
    return true
  }
  public func changeNextVersion(
    cfg: Configuration,
    product: String,
    version: String
  ) throws -> Bool {
    try perform(cfg: cfg, mutate: { storage in
      try storage.change(product: product, nextVersion: version)
      return cfg.createFlowStorageCommitMessage(
        flow: storage.flow,
        reason: .changeNextVersion,
        product: product,
        version: version
      )
    })
    return true
  }
  public func deleteTag(cfg: Configuration, name: String) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let tag = try name.isEmpty.not
      .then(Git.Tag.make(name: name))
      .get(.make(job: cfg.gitlab.map(\.job).get()))
    try perform(cfg: cfg, mutate: { storage in
      var message: Generate? = nil
      if let stage = storage.stages[tag] {
        storage.stages[tag] = nil
        cfg.reportStageTagDeleted(stage: stage)
        message = cfg.createFlowStorageCommitMessage(
          flow: storage.flow,
          reason: .deleteStageTag,
          product: stage.product,
          version: stage.version.value,
          build: stage.build.value,
          branch: stage.branch.name,
          tag: stage.tag.name
        )
      }
      if let deploy = storage.deploys[tag] {
        storage.deploys[tag] = nil
        cfg.reportDeployTagDeleted(deploy: deploy, release: storage.release(deploy: deploy))
        message = cfg.createFlowStorageCommitMessage(
          flow: storage.flow,
          reason: .deleteDeployTag,
          product: deploy.product,
          version: deploy.version.value
        )
      }
      return message
    })
    try gitlab.deleteTag(name: name)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func deleteBranch(cfg: Configuration, name: String) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let project = try gitlab.project.get()
    let branch: Git.Branch
    if let name = name.isEmpty.not.then(name) {
      branch = try .make(name: name)
    } else {
      branch = try .make(job: gitlab.job)
      let sha = try Git.Ref.make(sha: .make(job: gitlab.job))
      guard try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: sha,
        parent: .make(remote: branch)
      ))) else { throw Thrown("Not last commit pipeline") }
      guard try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: .make(name: project.defaultBranch)),
        parent: sha
      ))) else { throw Thrown("Branch \(branch.name) not merged into \(project.defaultBranch)") }
    }
    try perform(cfg: cfg, mutate: { storage in
      var message: Generate? = nil
      if let accessory = storage.accessories[branch] {
        storage.accessories[branch] = nil
        cfg.reportAccessoryBranchDeleted(accessory: accessory)
        message = cfg.createFlowStorageCommitMessage(
          flow: storage.flow,
          reason: .deleteAccessoryBranch,
          branch: branch.name
        )
      }
      if let release = storage.releases[branch] {
        storage.releases[branch] = nil
        cfg.reportReleaseBranchDeleted(release: release, kind: storage.kind(release: release))
        message = cfg.createFlowStorageCommitMessage(
          flow: storage.flow,
          reason: .deleteReleaseBranch,
          product: release.product,
          version: release.version.value,
          branch: release.branch.name
        )
      }
      return message
    })
    try gitlab.deleteBranch(name: branch.name)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func createDeployTag(cfg: Configuration) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let branch = try Git.Branch.make(job: gitlab.job)
    let sha = try Git.Sha.make(job: gitlab.job)
    try perform(cfg: cfg, mutate: { storage in
      guard let release = storage.releases[branch]
      else { throw Thrown("No release branch \(branch.name)") }
      let product = try storage.product(name: release.product)
      var family = try storage.family(name: product.family)
      let deploy = try Flow.Deploy.make(
        release: release,
        build: family.nextBuild,
        tag: generate(cfg.createTagName(
          flow: storage.flow,
          product: release.product,
          version: release.version,
          build: family.nextBuild,
          deploy: true
        ))
      )
      guard storage.deploys[deploy.tag] == nil
      else { throw Thrown("Deploy already exists \(deploy.tag.name)") }
      storage.deploys[deploy.tag] = deploy
      try family.bump(build: generate(cfg.bumpBuild(flow: storage.flow, family: family)))
      storage.families[family.name] = family
      let annotation = try generate(cfg.createTagAnnotation(
        flow: storage.flow,
        product: deploy.product,
        version: deploy.version,
        build: deploy.build,
        deploy: true
      ))
      guard try gitlab
        .postTags(name: deploy.tag.name, ref: sha.value, message: annotation)
        .map(execute)
        .map(Execute.parseData(reply:))
        .reduce(Json.GitlabTag.self, jsonDecoder.decode(_:from:))
        .get()
        .protected
      else { throw Thrown("Tag not protected \(deploy.tag.name)") }
      try cfg.reportDeployTagCreated(
        release: release,
        deploy: deploy,
        notes: makeNotes(cfg: cfg, storage: storage, release: release, deploy: sha)
      )
      try cfg.reportReleaseBranchSummary(release: release, deploy: deploy, notes: makeNotes(
        cfg: cfg, storage: storage, release: release
      ))
      return cfg.createFlowStorageCommitMessage(
        flow: storage.flow,
        reason: .createDeployTag,
        product: deploy.product,
        version: deploy.version.value,
        build: deploy.build.value,
        branch: release.branch.name,
        tag: deploy.tag.name
      )
    })
    return true
  }
  public func startRelease(cfg: Configuration, product: String, commit: String) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let commit = try commit.isEmpty.not
      .then(Git.Sha.make(value: commit))
      .get(.make(job: gitlab.job))
    try perform(cfg: cfg, mutate: { storage in
      var product = try storage.product(name: product)
      let release = try Flow.Release.make(
        product: product,
        version: product.nextVersion,
        commit: commit,
        branch: generate(cfg.createReleaseBranchName(
          flow: storage.flow,
          product: product.name,
          version: product.nextVersion,
          hotfix: false
        ))
      )
      guard storage.releases[release.branch] == nil
      else { throw Thrown("Release \(release.branch.name) already exists") }
      storage.releases[release.branch] = release
      try product.bump(version: generate(cfg.bumpVersion(
        flow: storage.flow,
        product: release.product,
        version: release.version,
        hotfix: false
      )))
      storage.products[product.name] = product
      guard try gitlab
        .postBranches(name: release.branch.name, ref: commit.value)
        .map(execute)
        .map(Execute.parseData(reply:))
        .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
        .get()
        .protected
      else { throw Thrown("Release \(release.branch.name) not protected") }
      cfg.reportReleaseBranchCreated(
        release: release,
        kind: .release
      )
      try cfg.reportReleaseBranchSummary(release: release, deploy: nil, notes: makeNotes(
        cfg: cfg, storage: storage, release: release
      ))
      return cfg.createFlowStorageCommitMessage(
        flow: storage.flow,
        reason: .createReleaseBranch,
        product: release.product,
        version: release.version.value,
        branch: release.branch.name
      )
    })
    return true
  }
  public func startHotfix(
    cfg: Configuration,
    product: String,
    commit: String,
    version: String
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    try perform(cfg: cfg, mutate: { storage in
      let fixProduct: Flow.Product
      let fixVersion: AlphaNumeric
      let fixCommit: Git.Sha
      if let commit = try commit.isEmpty.not.then(Git.Sha.make(value: commit)) {
        fixCommit = commit
        fixVersion = version.alphaNumeric
        let product = try storage.product(name: product)
        fixProduct = product
      } else {
        let tag = try Git.Tag.make(job: gitlab.job)
        guard let deploy = storage.deploys[tag]
        else { throw Thrown("No deploy for \(tag.name)") }
        fixVersion = deploy.version
        let product = try storage.product(name: deploy.product)
        fixProduct = product
        fixCommit = try Git.Sha.make(value: Execute.parseText(
          reply: execute(cfg.git.getSha(ref: .make(tag: tag)))
        ))
      }
      let version = try generate(cfg.bumpVersion(
        flow: storage.flow, product: fixProduct.name, version: fixVersion, hotfix: true
      )).alphaNumeric
      let release = try Flow.Release.make(
        product: fixProduct,
        version: version,
        commit: fixCommit,
        branch: generate(cfg.createReleaseBranchName(
          flow: storage.flow, product: fixProduct.name, version: version, hotfix: true
        ))
      )
      guard let min = fixProduct.prevVersions.min()
      else { throw Thrown("No previous releases of \(fixProduct.name)") }
      guard min < version
      else { throw Thrown("Version \(version.value) must be greater than \(min.value)") }
      guard fixProduct.nextVersion > version else { throw Thrown(
        "Version \(version.value) must be less than \(fixProduct.nextVersion.value)"
      )}
      guard fixProduct.prevVersions.contains(version).not
      else { throw Thrown("Version \(version.value) is known release") }
      guard storage.releases[release.branch] == nil
      else { throw Thrown("Release \(release.branch.name) already exists") }
      storage.releases[release.branch] = release
      guard try gitlab
        .postBranches(name: release.branch.name, ref: fixCommit.value)
        .map(execute)
        .map(Execute.parseData(reply:))
        .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
        .get()
        .protected
      else { throw Thrown("Release \(release.branch.name) not protected") }
      cfg.reportReleaseBranchCreated(
        release: release,
        kind: .hotfix
      )
      try cfg.reportReleaseBranchSummary(release: release, deploy: nil, notes: makeNotes(
        cfg: cfg, storage: storage, release: release
      ))
      return cfg.createFlowStorageCommitMessage(
        flow: storage.flow,
        reason: .createReleaseBranch,
        product: release.product,
        version: release.version.value,
        branch: release.branch.name
      )
    })
    return true
  }
  public func createAccessoryBranch(
    cfg: Configuration,
    name: String
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let accessory = try Flow.Accessory.make(branch: name)
    try perform(cfg: cfg, mutate: { storage in
      guard storage.accessories[accessory.branch] == nil else { throw Thrown(
        "Branch \(accessory.branch.name) already present"
      )}
      storage.accessories[accessory.branch] = accessory
      guard try gitlab
        .postBranches(name: name, ref: gitlab.job.pipeline.sha)
        .map(execute)
        .map(Execute.parseData(reply:))
        .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
        .get()
        .protected
      else { throw Thrown("\(name) not protected") }
      cfg.reportAccessoryBranchCreated(accessory: accessory)
      return cfg.createFlowStorageCommitMessage(
        flow: storage.flow, reason: .createAccessoryBranch, branch: accessory.branch.name
      )
    })
    return true
  }
  public func reserveBuild(cfg: Configuration, review: Bool, product: String) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    try perform(cfg: cfg, mutate: { storage in
      let product = try storage.product(name: product)
      var family = try storage.family(name: product.family)
      let build: Flow.Build
      let message: Generate
      if review {
        let parent = try gitlab.parent.get()
        let merge = try gitlab.merge.get()
        let sha = try Git.Sha.make(job: parent)
        let branch = try Git.Branch.make(name: merge.targetBranch)
        guard family.build(review: merge.iid, commit: sha) == nil else { return nil }
        build = .make(number: family.nextBuild, review: merge.iid, commit: sha, branch: branch)
        message = cfg.createFlowStorageCommitMessage(
          flow: storage.flow,
          reason: .reserveReviewBuild,
          build: build.number.value,
          review: merge.iid
        )
      } else {
        let branch = try Git.Branch.make(job: gitlab.job)
        let sha = try Git.Sha.make(job: gitlab.job)
        guard family.build(commit: sha, branch: branch) == nil else { return nil }
        build = .make(number: family.nextBuild, review: nil, commit: sha, branch: branch)
        message = cfg.createFlowStorageCommitMessage(
          flow: storage.flow,
          reason: .reserveBranchBuild,
          build: build.number.value,
          branch: branch.name
        )
      }
      family.builds[build.number] = build
      try family.bump(build: generate(cfg.bumpBuild(flow: storage.flow, family: family)))
      storage.families[family.name] = family
      return message
    })
    return true
  }
  public func stageBuild(
    cfg: Configuration,
    build: String,
    product: String
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    try perform(cfg: cfg, mutate: { storage in
      let product = try storage.product(name: product)
      let family = try storage.family(name: product.family)
      guard let build = family.builds[build.alphaNumeric] else { throw Thrown(
        "No build \(build) for \(product.name) reserved"
      )}
      let version = storage.releases[build.branch].map(\.version)
        .flatMapNil(storage.accessories[build.branch]?.versions[product.name])
        .get(product.nextVersion)
      let stage = try Flow.Stage.make(
        tag: generate(cfg.createTagName(
          flow: storage.flow,
          product: product.name,
          version: version,
          build: build.number,
          deploy: false
        )),
        product: product,
        version: version,
        build: build.number,
        review: build.review,
        branch: build.branch
      )
      guard storage.stages[stage.tag] == nil else { throw Thrown(
        "Tag \(stage.tag.name) already exists"
      )}
      storage.stages[stage.tag] = stage
      let annotation = try generate(cfg.createTagAnnotation(
        flow: storage.flow,
        product: stage.product,
        version: stage.version,
        build: stage.build,
        deploy: false
      ))
      guard try gitlab
        .postTags(name: stage.tag.name, ref: build.commit.value, message: annotation)
        .map(execute)
        .map(Execute.parseData(reply:))
        .reduce(Json.GitlabTag.self, jsonDecoder.decode(_:from:))
        .get()
        .protected
      else { throw Thrown("Stage not protected \(stage.tag.name)") }
      cfg.reportStageTagCreated(stage: stage)
      return cfg.createFlowStorageCommitMessage(
        flow: storage.flow,
        reason: .createStageTag,
        product: stage.product,
        version: stage.version.value,
        build: stage.build.value,
        review: stage.review,
        branch: (stage.review != nil).then(stage.branch.name),
        tag: stage.tag.name
      )
    })
    return true
  }
  public func renderVersions(
    cfg: Configuration,
    product: String,
    stdin: Configuration.ParseStdin,
    args: [String]
  ) throws -> Bool {
    let stdin = try parseStdin(stdin)
    let flow = try cfg.parseFlow.map(parseFlow).get()
    let storage = try parseFlowStorage(cfg.parseFlowStorage(flow: flow))
    var versions = storage.products.mapValues(\.nextVersion.value)
    guard product.isEmpty.not else {
      try writeStdout(generate(cfg.exportVersions(
        flow: flow, stdin: stdin, args: args, versions: versions, build: nil, product: nil
      )))
      return true
    }
    let product = try storage.product(name: product)
    let family = try storage.family(name: product.family)
    let gitlab = try cfg.gitlab.get()
    let sha = try Git.Sha.make(job: gitlab.job)
    let build: String
    if gitlab.job.tag {
      let tag = try Git.Tag.make(job: gitlab.job)
      if let deploy = storage.deploys[tag] {
        guard deploy.product == product.name else { throw Thrown(
          "Not \(product.name) deploy tag: \(tag.name)"
        )}
        build = deploy.build.value
        versions[product.name] = deploy.version.value
      } else if let stage = storage.stages[tag] {
        guard stage.product == product.name else { throw Thrown(
          "Not \(product.name) stage tag: \(tag.name)"
        )}
        build = stage.build.value
        versions[product.name] = stage.version.value
      } else {
        throw Thrown("No deploy or stage for tag \(tag.name)")
      }
    } else if let review = try? gitlab.job.review.get() {
      guard let present = family.build(review: review, commit: sha) else { throw Thrown(
        "No builds reserved for review \(review) sha \(sha.value)"
      )}
      build = present.number.value
      if let version = storage.version(product: product, build: present)?.value {
        versions[product.name] = version
      }
    } else {
      let branch = try Git.Branch.make(job: gitlab.job)
      guard let present = family.build(commit: sha, branch: branch) else { throw Thrown(
        "No builds reserved for branch \(branch.name) sha \(sha.value)"
      )}
      build = present.number.value
      if let version = storage.version(product: product, build: present)?.value {
        versions[product.name] = version
      }
    }
    try writeStdout(generate(cfg.exportVersions(
      flow: flow, stdin: stdin, args: args, versions: versions, build: build, product: product.name
    )))
    return true
  }
  func makeNotes(
    cfg: Configuration,
    storage: Flow.Storage,
    release: Flow.Release,
    deploy: Git.Sha? = nil
  ) throws -> Flow.ReleaseNotes {
    let commit: Git.Sha
    var refs = storage.deploys.values
      .filter(release.include(deploy:))
      .map(\.tag)
      .map(Git.Ref.make(tag:))
    if let deploy = deploy {
      commit = deploy
      refs.append(.make(sha: release.start))
    } else {
      commit = release.start
    }
    if commit != release.start { refs.append(.make(sha: release.start)) }
    let previous = try Id(refs)
      .map(cfg.git.excludeParents(refs:))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .map(Git.Sha.make(value:))
      .map(Git.Ref.make(sha:))
    guard previous.isEmpty.not else { return .make(uniq: [], lack: []) }
    var trees: Set<String> = []
    let uniq = try Execute
      .parseLines(reply: execute(cfg.git.listCommits(
        in: [.make(sha: commit)],
        notIn: previous,
        ignoreMissing: true
      )))
      .map(Git.Sha.make(value:))
      .filter({ sha in try trees
        .insert(Execute
          .parseText(reply: execute(cfg.git.patchId(ref: .make(sha: sha))))
          .dropSuffix(sha.value)
        )
        .inserted
      })
      .compactMap({ sha in try storage.flow.makeNote(sha: sha.value, msg: Execute.parseText(
        reply: execute(cfg.git.getCommitMessage(ref: .make(sha: sha)))
      ))})
    let lack = try Execute
      .parseLines(reply: execute(cfg.git.listCommits(
        in: previous,
        notIn: [.make(sha: commit)],
        ignoreMissing: true
      )))
      .map(Git.Sha.make(value:))
      .filter({ sha in try trees
        .insert(Execute
          .parseText(reply: execute(cfg.git.patchId(ref: .make(sha: sha))))
          .dropSuffix(sha.value)
        )
        .inserted
      })
      .compactMap({ sha in try storage.flow.makeNote(sha: sha.value, msg: Execute.parseText(
        reply: execute(cfg.git.getCommitMessage(ref: .make(sha: sha)))
      ))})
    return Flow.ReleaseNotes.make(uniq: uniq, lack: lack)
  }
}
extension Producer {
  func perform(cfg: Configuration, mutate: Try.In<Flow.Storage>.Do<Generate?>) throws {
    let flow = try cfg.parseFlow.map(parseFlow).get()
    var storage = try parseFlowStorage(cfg.parseFlowStorage(flow: flow))
    guard let message = try mutate(&storage).map(generate) else { return }
    _ = try persistAsset(.init(
      cfg: cfg,
      asset: flow.storage,
      content: storage.serialized,
      message: message
    ))
  }
}
