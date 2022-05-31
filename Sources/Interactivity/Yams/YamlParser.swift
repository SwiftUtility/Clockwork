import Foundation
import Yams
import Facility
import FacilityQueries
public enum YamlParser {
  public static func decodeYaml(query: DecodeYaml) throws -> AnyCodable {
    let any = try load(yaml: query.content)
    return try .init(any: any)
  }
}
