import Foundation
import Facility
public enum Plist {
  public struct Provision: Codable {
    public var uuid: String
    enum CodingKeys: String, CodingKey {
      case uuid = "UUID"
    }
  }
}
