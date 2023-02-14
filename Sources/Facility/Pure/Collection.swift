import Foundation
import Facility
public extension Collection {
  func indexed<T: Hashable>(_ keyPath: KeyPath<Element, T>) -> [T: Element] {
    reduce(into: [:], { $0[$1[keyPath: keyPath]] = $1 })
  }
}
public extension Collection where Element: Comparable {
  var sortedNonEmpty: [Element]? { self.isEmpty.not.then(self.sorted()) }
}
