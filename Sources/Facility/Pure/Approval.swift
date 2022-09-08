import Foundation
import Facility
public struct Approval {
  public var sanityTeam: String
  public var teams: [String: Team]
  public var emergencyTeam: String?
  public struct Team {
  }
}
