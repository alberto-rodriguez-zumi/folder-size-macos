import SwiftUI

// This fixture builds the chart independently of the filesystem scanner.
struct Entry: Identifiable {
    let id: URL
    let directory: Bool
    var size: Int64
    var children: [Entry]
    var partial: Bool
    var needsScan = false
}

@main
struct ChartLayoutTests {
    @MainActor
    static func main() {
        func item(_ path: String, size: Int64, children: [Entry] = [], directory: Bool = false) -> Entry {
            Entry(id: URL(fileURLWithPath: path), directory: directory || !children.isEmpty, size: size, children: children, partial: false)
        }
        let smallFiles = (0..<700).map { item("/root/Library/Containers/file-\($0)", size: 1) }
        let containers = item("/root/Library/Containers", size: 700, children: smallFiles)
        let cacheFile = item("/root/Library/Caches/large", size: 400)
        let caches = item("/root/Library/Caches", size: 400, children: [cacheFile])
        let supportFile = item("/root/Library/Application Support/large", size: 100)
        let support = item("/root/Library/Application Support", size: 100, children: [supportFile])
        let library = item("/root/Library", size: 1200, children: [containers, caches, support])
        let root = item("/root", size: 1200, children: [library])

        for minimum: Int64 in [0, 10] {
            let view = VisualExplorer(root: root, scanRoot: root.id, radial: false, showHidden: true, minimum: minimum, maxDepth: 4,
                                      select: { _ in }, open: { _ in }, analyze: { _ in }, showInFinder: { _ in },
                                      openTerminal: { _ in }, showProperties: { _ in })
            let tiles = view.makeTiles(in: CGRect(x: 0, y: 0, width: 1200, height: 800))
            let sectors = view.makeSectors()
            for important in [cacheFile, supportFile] {
                precondition(tiles.contains { $0.entry.id == important.id }, "Missing important tile with threshold \(minimum)")
                precondition(sectors.contains { $0.entry.id == important.id }, "Missing important sector with threshold \(minimum)")
            }
            precondition(tiles.count <= 600 && sectors.count <= 600)
        }
        let unfiltered = VisualExplorer(root: root, scanRoot: root.id, radial: false, showHidden: true, minimum: 0, maxDepth: 4,
                                        select: { _ in }, open: { _ in }, analyze: { _ in }, showInFinder: { _ in },
                                        openTerminal: { _ in }, showProperties: { _ in })
        let filtered = VisualExplorer(root: root, scanRoot: root.id, radial: false, showHidden: true, minimum: 500, maxDepth: 4,
                                      select: { _ in }, open: { _ in }, analyze: { _ in }, showInFinder: { _ in },
                                      openTerminal: { _ in }, showProperties: { _ in })
        for bounds in [CGRect(x: 0, y: 0, width: 1200, height: 800), CGRect(x: 0, y: 0, width: 300, height: 240)] {
            let allTiles = Set(unfiltered.makeTiles(in: bounds).map(\.id))
            let filteredTiles = Set(filtered.makeTiles(in: bounds).map(\.id))
            precondition(filteredTiles.isSubset(of: allTiles), "The size filter introduced new tiles")
        }
        let allSectors = Set(unfiltered.makeSectors().map(\.id))
        let filteredSectors = Set(filtered.makeSectors().map(\.id))
        precondition(filteredSectors.isSubset(of: allSectors), "The size filter introduced new sectors")
        print("Chart layout regression checks passed")
    }
}
