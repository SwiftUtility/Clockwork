import Foundation
import Facility
import FacilityAutomates
public struct RenderStencil: Query {
  public var template: String
  public var templates: [String: String]
  public var context: Encodable
  public typealias Reply = String?
}
public extension Configuration {
  func makeRenderStencil(context: Encodable, template: String) -> RenderStencil { .init(
    template: template,
    templates: templates,
    context: context
  )}
  func makeRenderStencil(merge: Configuration.Merge) -> RenderStencil { .init(
    template: merge.template,
    templates: templates,
    context: Configuration.Merge.Context.make(cfg: self, merge: merge)
  )}
  func makeRenderIntegrationJob(target: String) throws -> RenderStencil { try .init(
    template: profile.integrationJobTemplate
      .or { throw Thrown("Integration not configured localliy") },
    templates: profile.templates,
    context: ["target": target]
  )}
}
