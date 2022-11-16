import Foundation
import Facility
public struct Jira {
  public struct Context: Encodable {
    var url: String
    var epic: String?
    var issue: String?
  }
}
