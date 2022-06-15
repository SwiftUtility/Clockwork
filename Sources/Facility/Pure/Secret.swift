import Foundation
import Facility
public enum Secret {
  case value(String)
  case envVar(String)
  case envFile(String)
  public init(yaml: Yaml.Secret) throws {
    if let value = yaml.value { self = .value(value) }
    else if let envVar = yaml.envVar { self = .envVar(envVar) }
    else if let envFile = yaml.envFile { self = .envFile(envFile) }
    else { throw Thrown("secret is neither value, envVar nor envFile") }
  }
}
