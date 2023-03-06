import Foundation
import Yams
import Facility
import FacilityPure
public enum YamlParser {
  public static func decodeYaml(query: Yaml.Decode) throws -> AnyCodable {
    let any = try load(yaml: query.content)
    return try .init(any: any)
  }
  public static func decodeYaml(content: String) throws -> AnyCodable {
    let any = try load(yaml: content)
    return try .init(any: any)
  }
}
