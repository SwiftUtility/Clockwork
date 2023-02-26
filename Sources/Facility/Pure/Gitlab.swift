import Foundation
import Facility
public struct Gitlab {
  public var env: Env
  public let job: Json.GitlabJob
  public var api: String
  public var notes: [Note]
  public var review: Configuration.Template?
  public var trigger: Yaml.Gitlab.Trigger
  public var storage: Storage
  public var rest: Lossy<Rest> = .error(Thrown("Not protected ref pipeline"))
  public var deployKey: Lossy<String> = .error(Thrown("Not protected ref pipeline"))
  public var parent: Lossy<Json.GitlabJob> = .error(Thrown("Not triggered pipeline"))
  public var merge: Lossy<Json.GitlabMergeState> = .error(Thrown("Not review triggered pipeline"))
  public var info: Info { .init(
    mr: try? job.review.get(),
    url: job.webUrl
      .components(separatedBy: "/-/")
      .first,
    job: job,
    bot: try? rest.map(\.user).get(),
    proj: try? rest.map(\.project).get(),
    parent: try? parent.get(),
    merge: try? merge.get()
  )}
  public static func make(
    env: Env,
    job: Json.GitlabJob,
    storage: Storage,
    yaml: Yaml.Gitlab
  ) throws -> Self { try .init(
    env: env,
    job: job,
    api: "\(env.api)/projects/\(job.pipeline.projectId)",
    notes: yaml.notes.get([:]).map(Note.make(mark:yaml:)),
    review: yaml.review.map(Configuration.Template.make(yaml:)),
    trigger: yaml.trigger,
    storage: storage
  )}
  public struct Note {
    public var mark: String
    public var text: Configuration.Template
    public var events: [[String]]
    public static func make(mark: String, yaml: Yaml.Gitlab.Note) throws -> Self { try .init(
      mark: mark,
      text: .make(yaml: yaml.text),
      events: yaml.events.map({ $0.components(separatedBy: "/") })
    )}
  }
  public struct Description {
    public var delimiter: String
    public var text: Configuration.Template
  }
  public struct Storage {
    public var asset: Configuration.Asset
    public var bots: Set<String>
    public var users: [String: User]
    public var reviews: [String: UInt]
    public var serialized: String {
      var result: String = ""
      let bots = bots.sorted().map({ "'\($0)'" }).joined(separator: ",")
      result += "bots: [\(bots)]\n"
      let users = users.values.sorted(\.login)
      result += "users:\(users.isEmpty.then(" {}").get(""))\n"
      for user in users {
        result += "  '\(user.login)':\n"
        result += "    active: \(user.active)\n"
        let watchTeams = user.watchTeams.sorted().joined(separator: "','")
        if watchTeams.isEmpty.not { result += "    watchTeams: ['\(watchTeams)']\n" }
        let watchAuthors = user.watchAuthors.sorted().joined(separator: "','")
        if watchAuthors.isEmpty.not { result += "    watchAuthors: ['\(watchAuthors)']\n" }
      }
      let reviews = reviews.sorted(\.key)
      result += "reviews:\(reviews.isEmpty.then(" {}").get(""))\n"
      for review in reviews {
        result += "  '\(review.key)': \(review.value)"
      }
      return result
    }
    public static func make(
      asset: Configuration.Asset,
      yaml: Yaml.Gitlab.Storage
    ) -> Self { .init(
      asset: asset,
      bots: Set(yaml.bots),
      users: yaml.users.map(User.make(login:yaml:)).indexed(\.login),
      reviews: yaml.reviews.get([:])
    )}
    public struct User {
      public var login: String
      public var active: Bool
      public var watchTeams: Set<String>
      public var watchAuthors: Set<String>
      public static func make(
        login: String,
        yaml: Yaml.Gitlab.Storage.User
      ) -> Self { .init(
        login: login,
        active: yaml.active,
        watchTeams: yaml.watchTeams.get([]),
        watchAuthors: yaml.watchAuthors.get([])
      )}
      public static func make(login: String) -> Self { .init(
        login: login,
        active: true,
        watchTeams: [],
        watchAuthors: []
      )}
      public func makeUpdate(
        cfg: Configuration,
        reason: Generate.CreateGitlabStorageCommitMessage.Reason
      ) -> Update {
        .init(cfg: cfg, user: self, reason: reason)
      }
      public struct Update: Query {
        public var cfg: Configuration
        public var user: User
        public var reason: Generate.CreateGitlabStorageCommitMessage.Reason
        public typealias Reply = Void
      }
    }
    public enum Command {
      case activate
      case deactivate
      case register([Chat.Kind: String])
      case unwatchAuthors([String])
      case unwatchTeams([String])
      case watchAuthors([String])
      case watchTeams([String])
      public var reason: Generate.CreateGitlabStorageCommitMessage.Reason {
        switch self {
        case .activate: return .activateUser
        case .deactivate: return .deactivateUser
        case .register: return .registerUser
        default: return .updateUserWatchList
        }
      }
    }
  }
  public struct Info: Encodable {
    public var mr: UInt?
    public var url: String?
    public var job: Json.GitlabJob
    public var bot: Json.GitlabUser?
    public var proj: Json.GitlabProject?
    public var parent: Json.GitlabJob?
    public var merge: Json.GitlabMergeState?
  }
  public struct Parent {
    public let job: UInt
    public let profile: Files.Relative
  }
  public struct Rest {
    public let secret: String
    public let auth: String
    public let push: String
    public let user: Json.GitlabUser
    public let project: Json.GitlabProject
    public static func make(
      token: String,
      env: Env,
      user: Json.GitlabUser,
      project: Json.GitlabProject
    ) throws -> Self {
      guard var components = URLComponents(string: project.httpUrlToRepo)
      else { throw Thrown("Wrong url \(project.httpUrlToRepo)") }
      components.user = user.username
      components.password = token
      guard let push = components.string else { throw Thrown("Wrong url \(project.httpUrlToRepo)") }
      return .init(
        secret: token,
        auth: "Authorization: Bearer \(token)",
        push: push,
        user: user,
        project: project
      )
    }
  }
  public struct Env {
    public let api: String
    public let token: String
    public let parent: Lossy<UInt>
    public let storage: Configuration.Asset
    public var getJob: Lossy<Execute> {
      return .init(.makeCurl(
        url: "\(api)/job",
        headers: ["Authorization: Bearer \(token)"],
        secrets: [token]
      ))
    }
    public func getTokenUser(token: String) -> Lossy<Execute> { .init(.makeCurl(
      url: "\(api)/user",
      headers: ["Authorization: Bearer \(token)"],
      secrets: [token]
    ))}
    public func getProject(job: Json.GitlabJob, token: String) -> Lossy<Execute> { .init(.makeCurl(
      url: "\(api)/projects/\(job.pipeline.projectId)",
      headers: ["Authorization: Bearer \(token)"],
      secrets: [token]
    ))}
    public static func make(env: [String: String], yaml: Yaml.Gitlab) throws -> Self {
      guard "true" == env["GITLAB_CI"] else { throw Thrown("Not in GitlabCI context") }
      return try .init(
        api: "CI_API_V4_URL".get(env: env),
        token: "CI_JOB_TOKEN".get(env: env),
        parent: .init(try yaml.trigger.jobId.get(env: env).getUInt()),
        storage: .make(yaml: yaml.storage)
      )
    }
  }
}
public extension Gitlab {
  func getJob(
    id: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/jobs/\(id)",
    retry: 2,
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func loadArtifact(
    job: UInt,
    file: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/jobs/\(job)/artifacts/\(file)",
    retry: 2,
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func getPipeline(
    pipeline: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/pipelines/\(pipeline)",
    retry: 2,
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func getMrState(
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)?include_rebase_in_progress=true",
    retry: 2,
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func getMrAwarders(
    review: UInt,
    page: Int,
    count: Int
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)/award_emoji?page=\(page)&per_page=\(count)",
    retry: 2,
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func getMrDiscussions(
    review: UInt,
    page: Int,
    count: Int
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)/discussions?page=\(page)&per_page=\(count)",
    retry: 2,
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func postMrNotes(
    review: UInt,
    body: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)/notes",
    method: "POST",
    data: MrNote(body: body).curl.get(),
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func putMrNotes(
    review: UInt,
    note: UInt,
    body: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)/notes/\(note)",
    method: "PUT",
    data: MrNote(body: body).curl.get(),
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func postMrPipelines(
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)/pipelines",
    method: "POST",
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func postMrAward(
    review: UInt,
    award: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)/award_emoji",
    method: "POST",
    form: ["name=\(award)"],
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func putMrState(
    parameters: PutMrState,
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)",
    method: "PUT",
    data: parameters.curl.get(),
    headers: [rest.get().auth, Json.contentType],
    secrets: [rest.get().secret]
  ))}
  func putMrMerge(
    parameters: PutMrMerge,
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)/merge",
    method: "PUT",
    checkHttp: false,
    data: parameters.curl.get(),
    headers: [rest.get().auth, Json.contentType],
    secrets: [rest.get().secret]
  ))}
  func postTriggerPipeline(
    cfg: Configuration,
    ref: String,
    variables: [String: String]
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/trigger/pipeline",
    method: "POST",
    form: [
      "token=\(env.token)",
      "ref=\(ref)",
    ] + variables
      .map { try "variables[\($0.key)]=\($0.value.urlEncoded.get())" },
    secrets: [env.token]
  ))}
  func affectPipeline(
    cfg: Configuration,
    pipeline: UInt,
    action: PipelineAction
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/pipelines/\(pipeline)\(action.path)",
    method: action.method,
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func postMergeRequests(
    parameters: PostMergeRequests
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests",
    method: "POST",
    data: parameters.curl.get(),
    headers: [rest.get().auth, Json.contentType],
    secrets: [rest.get().secret]
  ))}
  func deleteMergeRequest(
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)",
    method: "DELETE",
    headers: [rest.get().auth, Json.contentType],
    secrets: [rest.get().secret]
  ))}
  func listShaMergeRequests(
    sha: Git.Sha
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/commits/\(sha.value)/merge_requests",
    retry: 2,
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func getJobs(
    action: JobAction,
    scopes: [JobScope],
    pipeline: UInt,
    page: Int,
    count: Int
  ) -> Lossy<Execute> {
    let query = [
      "include_retried=true",
      "page=\(page)",
      "per_page=\(count)",
    ] + scopes.flatMapEmpty(action.scopes).map { "scope[]=\($0.rawValue)" }
    return .init(try .makeCurl(
      url: "\(api)/pipelines/\(pipeline)/jobs?\(query.joined(separator: "&"))",
      retry: 2,
      headers: [rest.get().auth],
      secrets: [rest.get().secret]
    ))
  }
  func postJobsAction(
    job: UInt,
    action: JobAction
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/jobs/\(job)/\(action.rawValue)",
    method: "POST",
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func postTags(
    name: String,
    ref: String,
    message: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/tags",
    method: "POST",
    form: [
      "tag_name=\(name)",
      "ref=\(ref)",
      "message=\(message)",
    ],
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func postBranches(
    name: String,
    ref: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/branches",
    method: "POST",
    form: [
      "branch=\(name.urlEncoded.get())",
      "ref=\(ref)",
    ],
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func deleteBranch(name: String) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/branches/\(name.urlEncoded.get())",
    method: "DELETE",
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func deleteTag(name: String) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/tags/\(name.urlEncoded.get())",
    method: "DELETE",
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func getBranches(page: Int, count: Int) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/branches?page=\(page)&per_page=\(count)",
    retry: 2,
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  func getBranch(name: String) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/branches/\(name.urlEncoded.get())",
    retry: 2,
    headers: [rest.get().auth],
    secrets: [rest.get().secret]
  ))}
  struct PutMrState: Encodable {
    public var targetBranch: String?
    public var title: String?
    public var addLabels: String?
    public var removeLabels: String?
    public var stateEvent: String?
    public init(
      targetBranch: String? = nil,
      title: String? = nil,
      addLabels: String? = nil,
      removeLabels: String? = nil,
      stateEvent: String? = nil
    ) {
      self.targetBranch = targetBranch
      self.title = title
      self.addLabels = addLabels
      self.removeLabels = removeLabels
      self.stateEvent = stateEvent
    }
  }
  struct MrNote: Encodable {
    public var body: String
  }
  struct PutMrMerge: Encodable {
    public var mergeCommitMessage: String?
    public var squashCommitMessage: String?
    public var squash: Bool?
    public var shouldRemoveSourceBranch: Bool?
    public var mergeWhenPipelineSucceeds: Bool?
    public var sha: String?
    public init(
      mergeCommitMessage: String? = nil,
      squashCommitMessage: String? = nil,
      squash: Bool? = nil,
      shouldRemoveSourceBranch: Bool? = nil,
      mergeWhenPipelineSucceeds: Bool? = nil,
      sha: Git.Sha? = nil
    ) {
      self.mergeCommitMessage = mergeCommitMessage
      self.squashCommitMessage = squashCommitMessage
      self.squash = squash
      self.shouldRemoveSourceBranch = shouldRemoveSourceBranch
      self.mergeWhenPipelineSucceeds = mergeWhenPipelineSucceeds
      self.sha = sha?.value
    }
  }
  struct PostMergeRequests: Encodable {
    public var sourceBranch: String
    public var targetBranch: String
    public var title: String
    public init(
      sourceBranch: String,
      targetBranch: String,
      title: String
    ) {
      self.sourceBranch = sourceBranch
      self.targetBranch = targetBranch
      self.title = title
    }
  }
  enum PipelineAction: String {
    case cancel
    case delete
    case retry
    var path: String {
      switch self {
      case .cancel: return "/cancel"
      case .delete: return ""
      case .retry: return "/retry"
      }
    }
    var method: String {
      switch self {
      case .cancel: return "POST"
      case .delete: return "DELETE"
      case .retry: return "POST"
      }
    }
  }
  enum JobAction: String {
    case play
    case cancel
    case retry
    var scopes: [JobScope] {
      switch self {
      case .play: return [.manual]
      case .cancel: return [.pending, .running, .created]
      case .retry: return [.failed, .canceled, .success]
      }
    }
  }
  enum JobScope: String {
    case canceled
    case created
    case failed
    case manual
    case pending
    case running
    case success
  }
}
extension Encodable {
  var curl: Lossy<String> {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return Lossy(self)
      .map(encoder.encode(_:))
      .map(String.make(utf8:))
  }
}
extension String {
  var urlEncoded: Lossy<String> { .init(try self
    .addingPercentEncoding(withAllowedCharacters: .alphanumerics)
    .get { throw MayDay("addingPercentEncoding failed") }
  )}
}
