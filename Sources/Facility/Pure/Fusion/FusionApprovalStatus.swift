//import Foundation
//import Facility
//extension Fusion.Approval {
//  public struct Status {
//    public var review: UInt
//    public var target: String
//    public var authors: Set<String>
//    public var state: Yaml.Review.Approval.Status.State
//    public var skip: Set<Git.Sha> = []
//    public var teams: Set<String> = []
//    public var emergent: Git.Sha?
//    public var verified: Git.Sha?
//    public var randoms: Set<String> = []
//    public var legates: Set<String> = []
//    public var replicate: Git.Branch?
//    public var integrate: Git.Branch?
//    public var approves: [String: Approve] = [:]
//    public var merge: Bool { replicate != nil || integrate != nil }
//    mutating func invalidate(users: Set<String>) { approves
//      .filter(\.value.resolution.approved)
//      .keys
//      .filter(users.contains(_:))
//      .forEach { approves[$0]?.resolution = .outdated }
//    }
//    public var approvedCommits: Set<Git.Sha> { approves.values
//      .filter(\.resolution.approved)
//      .reduce(into: Set(emergent.array), { $0.insert($1.commit) })
//    }
//    public mutating func approve(
//      job: Json.GitlabJob,
//      approvers: [String: Gitlab.User],
//      resolution: Fusion.Approval.Status.Resolution
//    ) throws {
//      let user = try job.getLogin(approvers: approvers)
//      approves[user] = try .init(
//        approver: user,
//        commit: .make(job: job),
//        resolution: resolution
//      )
//    }
//    public mutating func setAuthor(
//      job: Json.GitlabJob,
//      approvers: [String: Gitlab.User],
//      rules: Fusion.Approval.Rules
//    ) throws -> Bool {
//      let user = try job.getLogin(approvers: approvers)
//      guard authors.contains(user).not else { return false }
//      authors.insert(user)
//      invalidate(users: rules.authorship
//        .filter({ $0.value.contains(user) })
//        .compactMap({ rules.teams[$0.key] })
//        .reduce(into: [user], { $0.formUnion($1.approvers) })
//      )
//      return true
//    }
//    public mutating func unsetAuthor(
//      job: Json.GitlabJob,
//      approvers: [String: Gitlab.User]
//    ) throws -> Bool {
//      let user = try job.getLogin(approvers: approvers)
//      invalidate(users: [user])
//      return authors.remove(user) != nil
//    }
//    public func reminds(sha: String, approvers: [String: Gitlab.User]) -> Set<String> {
//      guard emergent == nil else { return [] }
//      guard verified?.value == sha else { return [] }
//      return legates
//        .union(randoms)
//        .union(authors)
//        .union(approves.filter(\.value.resolution.block).keys)
//        .subtracting(approves.filter(\.value.resolution.approved).keys)
//        .intersection(approvers.filter(\.value.active).keys)
//    }
//    public func isWatched(by approver: Gitlab.User) -> Bool {
//      guard teams.isDisjoint(with: approver.watchTeams) else { return true }
//      guard authors.isDisjoint(with: approver.watchAuthors) else { return true }
//      return false
//    }
//    public static func make(
//      review: String,
//      yaml: Yaml.Review.Approval.Status
//    ) throws -> Self { try .init(
//      review: review.getUInt(),
//      target: yaml.target,
//      authors: Set(yaml.authors),
//      state: yaml.state,
//      skip: Set(yaml.skip.get([]).map(Git.Sha.make(value:))),
//      teams: Set(yaml.teams.get([])),
//      emergent: yaml.emergent.map(Git.Sha.make(value:)),
//      verified: yaml.verified.map(Git.Sha.make(value:)),
//      randoms: Set(yaml.randoms.get([])),
//      legates: Set(yaml.legates.get([])),
//      replicate: yaml.replicate.map(Git.Branch.make(name:)),
//      integrate: yaml.integrate.map(Git.Branch.make(name:)),
//      approves: yaml.approves.get([:])
//        .map(Approve.make(approver:yaml:))
//        .reduce(into: [:], { $0[$1.approver] = $1 })
//    )}
//    public static func serialize(statuses: [UInt: Self]) -> String {
//      var result = ""
//      for status in statuses.values.sorted(by: { $0.review < $1.review }) {
//        result += "'\(status.review)':\n"
//        result += "  target: '\(status.target)'\n"
//        let authors = status.authors
//          .sorted()
//          .map({ "'\($0)'" })
//          .joined(separator: ",")
//        result += "  authors: [\(authors)]\n"
//        result += "  state: \(status.state.rawValue)\n"
//        let skip = status.skip.map(\.value).sorted().map({ "'\($0)'" }).joined(separator: ",")
//        if skip.isEmpty.not { result += "  skip: [\(skip)]\n" }
//        let teams = status.teams.sorted().map({ "'\($0)'" }).joined(separator: ",")
//        if teams.isEmpty.not { result += "  teams: [\(teams)]\n" }
//        if let verified = status.verified?.value { result += "  verified: '\(verified)'\n" }
//        if let emergent = status.emergent?.value { result += "  emergent: '\(emergent)'\n" }
//        let legates = status.legates.sorted().map { "'\($0)'" }.joined(separator: ",")
//        if legates.isEmpty.not { result += "  legates: [\(legates)]\n" }
//        let randoms = status.randoms.sorted().map { "'\($0)'" }.joined(separator: ",")
//        if randoms.isEmpty.not { result += "  randoms: [\(randoms)]\n" }
//        if let replicate = status.replicate { result += "  replicate: '\(replicate.name)'\n" }
//        if let integrate = status.integrate { result += "  integrate: '\(integrate.name)'\n" }
//        let approves = status.approves.keys
//          .sorted()
//          .compactMap({ status.approves[$0] })
//          .map({ "    '\($0.approver)': {\($0.resolution.rawValue): '\($0.commit.value)'}\n" })
//        if approves.isEmpty.not { result += "  approves:\n" + approves.joined() }
//      }
//      return result.isEmpty.then("{}\n").get(result)
//    }
//    public static func make(
//      review: Json.GitlabReviewState,
//      bot: Json.GitlabUser
//    ) -> Self { .init(
//      review: review.iid,
//      target: review.targetBranch,
//      authors: Set([review.author.username]).filter({ $0 != bot.username }),
//      state: .normal
//    )}
//    public static func make(
//      review: Json.GitlabReviewState,
//      bot: Json.GitlabUser,
//      authors: Set<String>,
//      merge: Review.State.Infusion.Merge
//    ) -> Self { .init(
//      review: review.iid,
//      target: review.targetBranch,
//      authors: authors.filter({ $0 != bot.username }),
//      state: .normal,
//      replicate: merge.replicate.then(merge.original),
//      integrate: merge.integrate.then(merge.original),
//      approves: authors.reduce(into: [:], {
//        $0[$1] = .init(approver: $1, commit: merge.fork, resolution: .fragil)
//      })
//    )}
//    public enum Resolution: String {
//      case block
//      case fragil
//      case advance
//      case outdated
//      public var approved: Bool {
//        switch self {
//        case .fragil, .advance: return true
//        case .block, .outdated: return false
//        }
//      }
//      public var fragil: Bool {
//        switch self {
//        case .fragil: return true
//        default: return false
//        }
//      }
//      public var block: Bool {
//        switch self {
//        case .block: return true
//        default: return false
//        }
//      }
//      public var outdated: Bool {
//        switch self {
//        case .outdated: return true
//        default: return false
//        }
//      }
//    }
//    public struct Approve {
//      public var approver: String
//      public var commit: Git.Sha
//      public var resolution: Resolution
//      public static func make(
//        approver: String,
//        yaml: [String: String]
//      ) throws -> Self {
//        guard yaml.count == 1, let yaml = yaml.first else { throw Thrown("Bad approve format") }
//        return try .init(
//          approver: approver,
//          commit: .make(value: yaml.value),
//          resolution:  .init(rawValue: yaml.key)
//            .get { throw Thrown("Bad resolution format") }
//        )
//      }
//    }
//  }
//}
