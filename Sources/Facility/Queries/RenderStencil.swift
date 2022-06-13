import Foundation
import Facility
import FacilityAutomates
public struct RenderStencil: Query {
  public var template: String
  public var templates: [String: String]
  public var context: Encodable
  public static func make(generator: Generator) -> Self { .init(
    template: generator.template,
    templates: generator.templates,
    context: generator.context
  )}
  public typealias Reply = String
}
extension Configuration.Controls {
  public func makeRenderStencil(
    template: String,
    context: Encodable
  ) -> RenderStencil { .init(
    template: template,
    templates: stencilTemplates,
    context: context
  )}
}
//public extension Configuration {
//  func makeRenderStencil(context: Encodable, template: String) -> RenderStencil { .init(
//    template: template,
//    templates: templates,
//    context: context
//  )}
//  func makeRenderStencil(merge: Configuration.Merge) -> RenderStencil { .init(
//    template: merge.template,
//    templates: templates,
//    context: Configuration.Merge.Context.make(cfg: self, merge: merge)
//  )}
//  func makeRenderIntegrationJob(template: String, target: String) throws -> RenderStencil { .init(
//    template: template,
//    templates: profile.templates,
//    context: ["target": target]
//  )}
//}
