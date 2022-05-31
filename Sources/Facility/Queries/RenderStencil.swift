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
    templates: stencil.templates,
    context: context
  )}
  func makeRenderStencil(merge: Configuration.Merge) -> RenderStencil { .init(
    template: merge.template,
    templates: stencil.templates,
    context: Configuration.Merge.Context.make(cfg: self, merge: merge)
  )}
}
