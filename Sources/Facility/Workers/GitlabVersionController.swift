import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
public struct GitlabVersionController {
  public init() {}
  public func createDeployTag(cfg: Configuration) throws -> Bool {
    throw MayDay("Not implemented")
  }
  public func createReleaseBranch(cfg: Configuration, product: String) throws -> Bool {
    throw MayDay("Not implemented")
  }
  public func createHotfixBranch(cfg: Configuration) throws -> Bool {
    throw MayDay("Not implemented")
  }
  public func reserveBuildNumber(cfg: Configuration) throws -> Bool {
    throw MayDay("Not implemented")
  }
  public func renderVersions(
    cfg: Configuration,
    template: String,
    build: Bool,
    branch: String
  ) throws -> Bool {
    throw MayDay("Not implemented")
  }
  public func reportReleaseNotes(cfg: Configuration, tag: String) throws -> Bool {
    throw MayDay("Not implemented")
  }
}
