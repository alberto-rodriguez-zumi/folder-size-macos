import Foundation

@main
struct ResultsSortTests {
    struct Item {
        let name: String
        let size: Int64
    }

    static func main() {
        let items = [Item(name: "zeta", size: 20), Item(name: "archivo 10", size: 10), Item(name: "archivo 2", size: 20)]
        var sort = ResultsSort()
        func names() -> [String] { sort.sorted(items, name: { $0.name }, size: { $0.size }).map(\.name) }
        precondition(names() == ["archivo 2", "zeta", "archivo 10"])
        sort.select(.size)
        precondition(names() == ["archivo 10", "archivo 2", "zeta"])
        sort.select(.name)
        precondition(names() == ["archivo 2", "archivo 10", "zeta"])
        sort.select(.name)
        precondition(names() == ["zeta", "archivo 10", "archivo 2"])
        sort.select(.size)
        precondition(names() == ["archivo 2", "zeta", "archivo 10"])
        print("Results sorting checks passed")
    }
}
