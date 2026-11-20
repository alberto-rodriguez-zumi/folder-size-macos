import SwiftUI

private struct Tile: Identifiable {
    let entry: Entry
    let rect: CGRect
    let depth: Int
    var id: URL { entry.id }
}

private struct Sector: Identifiable {
    let entry: Entry
    let start: Double
    let end: Double
    let depth: Int
    var id: URL { entry.id }
}

struct VisualExplorer: View {
    let root: Entry
    let radial: Bool
    let showHidden: Bool
    let minimum: Int64
    let select: (Entry) -> Void
    let open: (Entry) -> Void
    @State private var hovered: Entry?

    private func visible(_ entry: Entry) -> [Entry] {
        entry.children.filter { (showHidden || !$0.id.lastPathComponent.hasPrefix(".")) && (!$0.directory || $0.size >= minimum) && $0.size > 0 }
    }

    // Squarified treemap: group similarly sized items into rows with a good aspect ratio.
    private func rectangles(_ entries: [Entry], in bounds: CGRect, total: Int64) -> [(Entry, CGRect)] {
        guard total > 0, bounds.width > 0, bounds.height > 0 else { return [] }
        let areaScale = bounds.width * bounds.height / CGFloat(total)
        var remaining = bounds
        var result: [(Entry, CGRect)] = []
        var row: [Entry] = []
        func worst(_ row: [Entry], _ side: CGFloat) -> CGFloat {
            guard !row.isEmpty, side > 0 else { return .infinity }
            let areas = row.map { CGFloat($0.size) * areaScale }
            let sum = areas.reduce(0, +)
            guard let lo = areas.min(), let hi = areas.max(), lo > 0, sum > 0 else { return .infinity }
            return max(side * side * hi / (sum * sum), sum * sum / (side * side * lo))
        }
        func place(_ group: [Entry]) {
            let area = group.reduce(CGFloat.zero) { $0 + CGFloat($1.size) * areaScale }
            guard area > 0, remaining.width > 0, remaining.height > 0 else { return }
            if remaining.width >= remaining.height {
                let width = min(remaining.width, area / remaining.height)
                var y = remaining.minY
                for item in group {
                    let height = CGFloat(item.size) * areaScale / width
                    result.append((item, CGRect(x: remaining.minX, y: y, width: width, height: height)))
                    y += height
                }
                remaining.origin.x += width
                remaining.size.width -= width
            } else {
                let height = min(remaining.height, area / remaining.width)
                var x = remaining.minX
                for item in group {
                    let width = CGFloat(item.size) * areaScale / height
                    result.append((item, CGRect(x: x, y: remaining.minY, width: width, height: height)))
                    x += width
                }
                remaining.origin.y += height
                remaining.size.height -= height
            }
        }
        for entry in entries {
            if !row.isEmpty && worst(row + [entry], min(remaining.width, remaining.height)) > worst(row, min(remaining.width, remaining.height)) {
                place(row)
                row.removeAll(keepingCapacity: true)
            }
            row.append(entry)
        }
        place(row)
        return result
    }

    private func makeTiles(in bounds: CGRect) -> [Tile] {
        var result: [Tile] = []
        var queue: [(Entry, CGRect, Int)] = [(root, bounds, 0)]
        var index = 0
        while index < queue.count && result.count < 600 {
            let (node, rect, depth) = queue[index]
            index += 1
            guard depth < 5, rect.width > 3, rect.height > 3 else { continue }
            let children = visible(node)
            let total = children.reduce(Int64(0)) { $0 + $1.size }
            for (child, frame) in rectangles(children, in: rect, total: total) {
                guard result.count < 600 else { break }
                result.append(Tile(entry: child, rect: frame, depth: depth))
                if child.directory && frame.width > 45 && frame.height > 38 {
                    let inner = CGRect(x: frame.minX + 3, y: frame.minY + 19, width: max(0, frame.width - 6), height: max(0, frame.height - 22))
                    queue.append((child, inner, depth + 1))
                }
            }
        }
        return result
    }

    private func makeSectors() -> [Sector] {
        var result: [Sector] = []
        var queue: [(Entry, Double, Double, Int)] = [(root, 0, 360, 0)]
        var index = 0
        while index < queue.count && result.count < 600 {
            let (node, start, end, depth) = queue[index]
            index += 1
            guard depth < 5 else { continue }
            let children = visible(node)
            let total = children.reduce(Int64(0)) { $0 + $1.size }
            guard total > 0 else { continue }
            var angle = start
            for child in children {
                guard result.count < 600 else { break }
                let next = angle + (end - start) * Double(child.size) / Double(total)
                if next - angle >= 0.15 {
                    result.append(Sector(entry: child, start: angle, end: next, depth: depth))
                    queue.append((child, angle, next, depth + 1))
                }
                angle = next
            }
        }
        return result
    }

    private func color(_ entry: Entry, depth: Int) -> Color {
        let base = entry.id.pathComponents.dropFirst(root.id.pathComponents.count).first ?? entry.id.lastPathComponent
        var hash: UInt64 = 5381
        for byte in base.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        return Color(hue: Double(hash % 360) / 360, saturation: max(0.25, 0.55 - Double(depth) * 0.05), brightness: min(0.92, 0.70 + Double(depth) * 0.04))
    }

    var body: some View {
        GeometryReader { geometry in
            if radial {
                let dimension = min(geometry.size.width, geometry.size.height)
                ZStack(alignment: .top) {
                    Circle().fill(.quaternary).frame(width: dimension / 6, height: dimension / 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
                    Text(root.id.lastPathComponent).font(.caption).lineLimit(1).frame(width: dimension / 7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
                    ForEach(makeSectors()) { sector in
                        let shape = RingSegment(start: sector.start, end: sector.end, inner: CGFloat(sector.depth + 1) / 6, outer: CGFloat(sector.depth + 2) / 6)
                        shape.fill(color(sector.entry, depth: sector.depth)).overlay(shape.stroke(.background, lineWidth: 1))
                            .contentShape(shape).onTapGesture(count: 2) { open(sector.entry) }.onTapGesture { select(sector.entry) }
                            .onHover { inside in
                                if inside {
                                    hovered = sector.entry
                                } else if hovered?.id == sector.entry.id {
                                    hovered = nil
                                }
                            }
                            .contextMenu { if sector.entry.directory { Button("Abrir") { open(sector.entry) } } }
                            .help(sector.entry.id.lastPathComponent + " · " + ByteCountFormatter.string(fromByteCount: sector.entry.size, countStyle: .file))
                    }
                    if let hovered {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hovered.id.lastPathComponent).fontWeight(.medium)
                            Text(hovered.id.path).font(.caption).lineLimit(1).truncationMode(.middle)
                            Text(ByteCountFormatter.string(fromByteCount: hovered.size, countStyle: .file) + (hovered.partial ? " · parcial" : ""))
                                .font(.caption)
                        }
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .frame(maxWidth: min(dimension, 380), alignment: .leading)
                        .padding(8)
                        .allowsHitTesting(false)
                    }
                }.frame(width: dimension, height: dimension).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: root.id) { _, _ in hovered = nil }
            } else {
                let tiles = makeTiles(in: CGRect(origin: .zero, size: geometry.size))
                let parents = Set(tiles.map { $0.entry.id.deletingLastPathComponent().standardizedFileURL.path })
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(.quaternary)
                    ForEach(tiles) { tile in
                        ZStack(alignment: .topLeading) {
                            Rectangle().fill(color(tile.entry, depth: tile.depth)).overlay(Rectangle().stroke(.background, lineWidth: 1))
                            if tile.rect.width > 55 && tile.rect.height > 18 {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(tile.entry.id.lastPathComponent).lineLimit(1)
                                    if tile.rect.height > 34 && !parents.contains(tile.entry.id.standardizedFileURL.path) {
                                        Text(ByteCountFormatter.string(fromByteCount: tile.entry.size, countStyle: .file) + (tile.entry.partial ? " · parcial" : ""))
                                            .lineLimit(1)
                                    }
                                }
                                .font(.caption).padding(.horizontal, 4).foregroundStyle(.black)
                            }
                        }.frame(width: tile.rect.width, height: tile.rect.height).position(x: tile.rect.midX, y: tile.rect.midY)
                            .contentShape(Rectangle()).onTapGesture(count: 2) { open(tile.entry) }.onTapGesture { select(tile.entry) }
                            .contextMenu { if tile.entry.directory { Button("Abrir") { open(tile.entry) } } }
                            .help(tile.entry.id.lastPathComponent + " · " + ByteCountFormatter.string(fromByteCount: tile.entry.size, countStyle: .file))
                    }
                }.clipped()
            }
        }
    }
}

struct RingSegment: Shape {
    let start: Double
    let end: Double
    let inner: CGFloat
    let outer: CGFloat
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.addArc(center: center, radius: radius * outer, startAngle: .degrees(start - 90), endAngle: .degrees(end - 90), clockwise: false)
        path.addArc(center: center, radius: radius * inner, startAngle: .degrees(end - 90), endAngle: .degrees(start - 90), clockwise: true)
        path.closeSubpath()
        return path
    }
}

struct DirectoryTree: View {
    let entry: Entry
    let showHidden: Bool
    let open: (Entry) -> Void
    var body: some View {
        let children = entry.children.filter { $0.directory && (showHidden || !$0.id.lastPathComponent.hasPrefix(".")) }
        if children.isEmpty {
            Button(entry.id.lastPathComponent) { open(entry) }.buttonStyle(.plain)
        } else {
            DisclosureGroup {
                ForEach(children) { child in DirectoryTree(entry: child, showHidden: showHidden, open: open) }
            } label: { Button(entry.id.lastPathComponent) { open(entry) }.buttonStyle(.plain) }
        }
    }
}
