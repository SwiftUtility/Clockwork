import Foundation
import Facility
public extension Collection where Element: Comparable {
  var sortedNonEmpty: [Element]? { self.isEmpty.not.then(self.sorted()) }
}
