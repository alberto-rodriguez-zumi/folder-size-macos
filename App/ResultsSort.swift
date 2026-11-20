import Foundation

struct ResultsSort {
    enum Column { case name, size }

    private(set) var column: Column = .size
    private(set) var ascending = false

    mutating func select(_ newColumn: Column) {
        if column == newColumn {
            ascending.toggle()
        } else {
            column = newColumn
            ascending = newColumn == .name
        }
    }

    func sorted<Element>(_ elements: [Element], name: (Element) -> String, size: (Element) -> Int64) -> [Element] {
        elements.sorted { lhs, rhs in
            let nameOrder = name(lhs).localizedStandardCompare(name(rhs))
            if column == .size && size(lhs) != size(rhs) {
                return ascending ? size(lhs) < size(rhs) : size(lhs) > size(rhs)
            }
            if nameOrder != .orderedSame {
                return column == .name && !ascending ? nameOrder == .orderedDescending : nameOrder == .orderedAscending
            }
            return name(lhs) < name(rhs)
        }
    }
}
