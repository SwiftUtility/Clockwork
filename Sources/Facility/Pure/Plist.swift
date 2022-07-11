import Foundation
import Facility
public enum Plist {
  public struct Provision: Codable {
    public var uuid: String
    public var name: String
    public var expirationDate: Date
    enum CodingKeys: String, CodingKey {
      case uuid = "UUID"
      case name = "Name"
      case expirationDate = "ExpirationDate"
    }
  }
}
