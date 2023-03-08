import Foundation
import Facility
import FacilityPure
public extension ContextLocal {
  func cocoapodsRestoreSpecs() throws -> Bool {
    let cocoapods = try parseCocoapods()
    let specs = try sh.resolveAbsolute(.make(path: "~/.cocoapods/repos"))
    try deleteWrongSpecs(cocoapods: cocoapods, specs: specs)
    try installSpecs(cocoapods: cocoapods, specs: specs)
    try resetSpecs(cocoapods: cocoapods, specs: specs)
    return true
  }
  func cocoapodsUpdateSpecs() throws -> Bool {
    var cocoapods = try parseCocoapods()
    let specs = try sh.resolveAbsolute(.make(path: "~/.cocoapods/repos"))
    try deleteWrongSpecs(cocoapods: cocoapods, specs: specs)
    try installSpecs(cocoapods: cocoapods, specs: specs)
    try updateSpecs(cocoapods: &cocoapods, specs: specs)
    try sh.write(
      file: "\(repo.git.root)/\(cocoapods.path)",
      data: .init(cocoapods.yaml.utf8)
    )
    return true
  }
}
private extension ContextLocal {
  func deleteWrongSpecs(cocoapods: Cocoapods, specs: Ctx.Sys.Absolute) throws {
    guard let names = try? sh.listDirectories(specs) else { return }
    for name in names {
      let git = try Ctx.Git.make(root: .make(value: "\(specs.value)/\(name)"))
      guard let url = try? git.getOriginUrl(sh: sh) else { continue }
      for spec in cocoapods.specs {
        guard spec.url == url else { continue }
        if spec.name != name { try sh.delete(path: git.root.value) }
      }
    }
  }
  func installSpecs(cocoapods: Cocoapods, specs: Ctx.Sys.Absolute) throws {
    for spec in cocoapods.specs {
      let git = try Ctx.Git.make(root: .make(value: "\(specs.value)/\(spec.name)"))
      guard case nil = try? git.getSha(sh: sh, ref: .head) else { continue }
      try podAdd(spec: spec)
    }
  }
  func resetSpecs(cocoapods: Cocoapods, specs: Ctx.Sys.Absolute) throws {
    for spec in cocoapods.specs {
      let git = try Ctx.Git.make(root: .make(value: "\(specs.value)/\(spec.name)"))
      let sha = try git.getSha(sh: sh, ref: .head)
      guard sha != spec.sha else { continue }
      try podUpdate(spec: spec)
      try git.reset(sh: sh, ref: spec.sha.ref, hard: true)
      try git.clean(sh: sh, ignore: true)
    }
  }
  func updateSpecs(cocoapods: inout Cocoapods, specs: Ctx.Sys.Absolute) throws {
    for index in cocoapods.specs.indices {
      try podUpdate(spec: cocoapods.specs[index])
      cocoapods.specs[index].sha = try Ctx.Git
        .make(root: .make(value: "\(specs.value)/\(cocoapods.specs[index].name)"))
        .getSha(sh: sh, ref: .head)
    }
  }
  func podAdd(spec: Cocoapods.Spec) throws { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: ["bundle", "exec", "pod", "repo", "add", spec.name, spec.url]
    )))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func podUpdate(spec: Cocoapods.Spec) throws { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: ["bundle", "exec", "pod", "repo", "update", spec.name]
    )))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
}
