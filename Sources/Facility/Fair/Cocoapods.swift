import Foundation
import Facility
import FacilityPure
extension Cocoapods {
  func deleteWrongSpecs(ctx: Context, path: Ctx.Sys.Absolute) throws {
    guard let names = try? ctx.sh.listDirectories(path) else { return }
    for name in names {
      let git = try Ctx.Git.make(root: .make(value: "\(path.value)/\(name)"))
      guard let url = try? git.getOriginUrl(sh: ctx.sh) else { continue }
      for spec in specs {
        guard spec.url == url else { continue }
        if spec.name != name { try ctx.sh.sysDelete(path: git.root.value) }
      }
    }
  }
  func installSpecs(ctx: Context, path: Ctx.Sys.Absolute) throws {
    for spec in specs {
      let git = try Ctx.Git.make(root: .make(value: "\(path.value)/\(spec.name)"))
      guard case nil = try? git.getSha(sh: ctx.sh, ref: .head) else { continue }
      try ctx.sh.podAdd(name: spec.name, url: spec.url)
    }
  }
  func resetSpecs(ctx: Context, path: Ctx.Sys.Absolute) throws {
    for spec in specs {
      let git = try Ctx.Git.make(root: .make(value: "\(path.value)/\(spec.name)"))
      let sha = try git.getSha(sh: ctx.sh, ref: .head)
      guard sha != spec.sha else { continue }
      try ctx.sh.podUpdate(name: spec.name)
      try git.reset(sh: ctx.sh, ref: spec.sha.ref, hard: true)
      try git.clean(sh: ctx.sh, ignore: true)
    }
  }
  mutating func updateSpecs(ctx: Context, path: Ctx.Sys.Absolute) throws {
    for index in specs.indices {
      try ctx.sh.podUpdate(name: specs[index].name)
      specs[index].sha = try Ctx.Git
        .make(root: .make(value: "\(path.value)/\(specs[index].name)"))
        .getSha(sh: ctx.sh, ref: .head)
    }
  }
}
