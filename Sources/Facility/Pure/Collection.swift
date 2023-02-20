import Foundation
import Facility
public extension Collection {
  func indexed<T: Hashable>(_ keyPath: KeyPath<Element, T>) -> [T: Element] {
    reduce(into: [:], { $0[$1[keyPath: keyPath]] = $1 })
  }
  func sorted<T: Comparable>(_ keyPath: KeyPath<Element, T>) -> [Element] {
    sorted(by: { $0[keyPath: keyPath] < $1[keyPath: keyPath] })
  }
  var notEmpty: Self? { isEmpty.not.then(self) }
}
public extension Collection where Element: Comparable {
  var sortedNonEmpty: [Element]? { self.isEmpty.not.then(self.sorted()) }
}
