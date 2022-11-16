import Foundation
import Facility
extension Fusion.Approval {
  public struct Approver: Encodable {
    public var login: String
    public var active: Bool
    public var watchTeams: Set<String>
    public var watchAuthors: Set<String>
    public static func serialize(approvers this: [String: Self]) -> String {
      guard this.isEmpty.not else { return "{}" }
      var result: String = ""
      for approver in this.keys.sorted().compactMap({ this[$0] }) {
        result += "'\(approver.login)':\n"
        result += "  active: \(approver.active)\n"
        let watchTeams = approver.watchTeams.sorted().map({ "'\($0)'" }).joined(separator: ",")
        if watchTeams.isEmpty.not { result += "  watchTeams: [\(watchTeams)]\n" }
        let watchAuthors = approver.watchAuthors.sorted().map({ "'\($0)'" }).joined(separator: ",")
        if watchAuthors.isEmpty.not { result += "  watchAuthors: [\(watchAuthors)]\n" }
        if watchAuthors.isEmpty.not { result += "  watchAuthors: [\(watchAuthors)]\n" }
      }
      return result
    }
    public static func make(login: String, yaml: Yaml.Review.Approval.Approver) -> Self { .init(
      login: login,
      active: yaml.active,
      watchTeams: Set(yaml.watchTeams.get([])),
      watchAuthors: Set(yaml.watchAuthors.get([]))
    )}
    public static func make(login: String, active: Bool) -> Self { .init(
      login: login,
      active: active,
      watchTeams: [],
      watchAuthors: []
    )}
    public enum Command {
      case activate
      case deactivate
      case register(String)
      case unwatchAuthors([String])
      case unwatchTeams([String])
      case watchAuthors([String])
      case watchTeams([String])
      public var reason: Generate.CreateApproversCommitMessage.Reason {
        switch self {
        case .activate: return .activate
        case .deactivate: return .deactivate
        case .register: return .register
        case .unwatchAuthors: return .unwatchAuthors
        case .unwatchTeams: return .unwatchTeams
        case .watchAuthors: return .watchAuthors
        case .watchTeams: return .watchTeams
        }
      }
    }
  }
}
