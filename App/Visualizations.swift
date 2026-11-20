import SwiftUI

struct Tile: Identifiable {
    let entry: Entry
    let rect: CGRect
    let depth: Int
    var id: URL { entry.id }
}

struct Sector: Identifiable {
    let entry: Entry
    let start: Double
    let end: Double
    let depth: Int
    var id: URL { entry.id }
}

struct VisualExplorer: View {
    let root: Entry
    let scanRoot: URL
    let radial: Bool
    let showHidden: Bool
    let minimum: Int64
    let maxDepth: Int
    let select: (Entry) -> Void
    let open: (Entry) -> Void
    let analyze: (Entry) -> Void
    let showInFinder: (Entry) -> Void
    let openTerminal: (Entry) -> Void
    let showProperties: (Entry) -> Void
    @State private var hovered: Entry?

    private func relativePath(_ url: URL) -> String {
        let base = scanRoot.standardizedFileURL.pathComponents
        let components = url.standardizedFileURL.pathComponents
        guard components.starts(with: base) else { return url.path }
        let relative = components.dropFirst(base.count).joined(separator: "/")
        return relative.isEmpty ? "." : relative
    }

    private func tooltip(_ entry: Entry) -> String {
        let size = ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)
        return "\(relativePath(entry.id)) · \(size)\(entry.partial ? " · parcial" : "")"
    }

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

    func makeTiles(in bounds: CGRect) -> [Tile] {
        var result: [Tile] = []
        var level: [(Entry, CGRect)] = [(root, bounds)]
        for depth in 0..<maxDepth {
            var candidates: [Tile] = []
            for (node, rect) in level {
                guard rect.width > 3, rect.height > 3 else { continue }
                let children = visible(node)
                let total = children.reduce(Int64(0)) { $0 + $1.size }
                for (child, frame) in rectangles(children, in: rect, total: total) {
                    candidates.append(Tile(entry: child, rect: frame, depth: depth))
                }
            }
            candidates.sort {
                if $0.entry.size != $1.entry.size { return $0.entry.size > $1.entry.size }
                return $0.entry.id.path < $1.entry.id.path
            }
            let selected = candidates.prefix(600 - result.count)
            result.append(contentsOf: selected)
            level = selected.compactMap { tile in
                guard tile.entry.directory && tile.rect.width > 45 && tile.rect.height > 38 else { return nil }
                let inner = CGRect(x: tile.rect.minX + 3, y: tile.rect.minY + 19, width: max(0, tile.rect.width - 6), height: max(0, tile.rect.height - 22))
                return (tile.entry, inner)
            }
            if level.isEmpty || result.count >= 600 { break }
        }
        return result
    }

    func makeSectors() -> [Sector] {
        var result: [Sector] = []
        var level: [(Entry, Double, Double)] = [(root, 0, 360)]
        for depth in 0..<maxDepth {
            var candidates: [Sector] = []
            for (node, start, end) in level {
                let children = visible(node)
                let total = children.reduce(Int64(0)) { $0 + $1.size }
                guard total > 0 else { continue }
                var angle = start
                for child in children {
                    let next = angle + (end - start) * Double(child.size) / Double(total)
                    if next - angle >= 0.15 {
                        candidates.append(Sector(entry: child, start: angle, end: next, depth: depth))
                    }
                    angle = next
                }
            }
            candidates.sort {
                if $0.entry.size != $1.entry.size { return $0.entry.size > $1.entry.size }
                return $0.entry.id.path < $1.entry.id.path
            }
            let selected = candidates.prefix(600 - result.count)
            result.append(contentsOf: selected)
            level = selected.filter { $0.entry.directory }.map { ($0.entry, $0.start, $0.end) }
            if level.isEmpty || result.count >= 600 { break }
        }
        return result
    }

    private func radialEntry(at point: CGPoint, dimension: CGFloat, sectors: [Sector]) -> Entry? {
        guard dimension > 0 else { return nil }
        let x = point.x - dimension / 2
        let y = point.y - dimension / 2
        let radius = hypot(x, y) / (dimension / 2)
        let ring = Int(floor(radius * CGFloat(maxDepth + 1))) - 1
        guard ring >= 0 && ring < maxDepth else { return nil }
        let degrees = atan2(x, -y) * 180 / .pi
        let angle = degrees < 0 ? degrees + 360 : degrees
        return sectors.first { $0.depth == ring && angle >= $0.start && angle < $0.end }?.entry
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
                let sectors = makeSectors()
                ZStack(alignment: .top) {
                    Circle().fill(.quaternary).frame(width: dimension / CGFloat(maxDepth + 1), height: dimension / CGFloat(maxDepth + 1))
                        .frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
                    Text(root.id.lastPathComponent).font(.caption).lineLimit(1).frame(width: dimension / 7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
                    ForEach(sectors) { sector in
                        let shape = RingSegment(start: sector.start, end: sector.end, inner: CGFloat(sector.depth + 1) / CGFloat(maxDepth + 1), outer: CGFloat(sector.depth + 2) / CGFloat(maxDepth + 1))
                        shape.fill(color(sector.entry, depth: sector.depth)).overlay(shape.stroke(.background, lineWidth: 1))
                            .allowsHitTesting(false)
                    }
                    Color.clear
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                hovered = radialEntry(at: location, dimension: dimension, sectors: sectors)
                            case .ended:
                                hovered = nil
                            }
                        }
                        .gesture(
                            SpatialTapGesture(count: 2).exclusively(before: SpatialTapGesture())
                                .onEnded { result in
                                    switch result {
                                    case .first(let value):
                                        if let entry = radialEntry(at: value.location, dimension: dimension, sectors: sectors) { open(entry) }
                                    case .second(let value):
                                        if let entry = radialEntry(at: value.location, dimension: dimension, sectors: sectors) { select(entry) }
                                    }
                                }
                        )
                        .contextMenu {
                            if let entry = hovered {
                                if entry.directory {
                                    Button("Abrir") { open(entry) }
                                    Button("Analizar") { analyze(entry) }
                                }
                                Button("Mostrar en Finder") { showInFinder(entry) }
                                Button("Abrir en Terminal") { openTerminal(entry) }
                                Button("Propiedades") { showProperties(entry) }
                            }
                        }
                    if let hovered {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hovered.id.lastPathComponent).fontWeight(.medium)
                            Text(relativePath(hovered.id)).font(.caption).lineLimit(1).truncationMode(.middle)
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
                    .onChange(of: maxDepth) { _, _ in hovered = nil }
                    .onChange(of: showHidden) { _, _ in hovered = nil }
                    .onChange(of: minimum) { _, _ in hovered = nil }
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
                                    if parents.contains(tile.entry.id.standardizedFileURL.path) {
                                        Text("\(tile.entry.id.lastPathComponent) · \(ByteCountFormatter.string(fromByteCount: tile.entry.size, countStyle: .file))\(tile.entry.partial ? " · parcial" : "")").lineLimit(1)
                                    } else {
                                        Text(tile.entry.id.lastPathComponent).lineLimit(1)
                                    }
                                    if tile.rect.height > 34 && !parents.contains(tile.entry.id.standardizedFileURL.path) {
                                        Text(ByteCountFormatter.string(fromByteCount: tile.entry.size, countStyle: .file) + (tile.entry.partial ? " · parcial" : ""))
                                            .lineLimit(1)
                                    }
                                }
                                .font(.caption).padding(.horizontal, 4).foregroundStyle(.black)
                            }
                        }.frame(width: tile.rect.width, height: tile.rect.height)
                            .contentShape(Rectangle()).onTapGesture(count: 2) { open(tile.entry) }.onTapGesture { select(tile.entry) }
                            .contextMenu {
                                if tile.entry.directory {
                                    Button("Abrir") { open(tile.entry) }
                                    Button("Analizar") { analyze(tile.entry) }
                                }
                                Button("Mostrar en Finder") { showInFinder(tile.entry) }
                                Button("Abrir en Terminal") { openTerminal(tile.entry) }
                                Button("Propiedades") { showProperties(tile.entry) }
                            }
                            .help(tooltip(tile.entry))
                            .position(x: tile.rect.midX, y: tile.rect.midY)
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
    let current: URL
    let showHidden: Bool
    let open: (Entry) -> Void
    let analyze: (Entry) -> Void
    let showInFinder: (Entry) -> Void
    let openTerminal: (Entry) -> Void
    let showProperties: (Entry) -> Void
    var isRoot = false
    @State private var isExpanded = false

    private var row: some View {
        Button { open(entry) } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(entry.id == current ? Color.white : Color.accentColor)
                Text(entry.id.lastPathComponent.isEmpty ? "/" : entry.id.lastPathComponent)
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 2)
                if entry.partial {
                    Image(systemName: "exclamationmark.circle")
                        .accessibilityLabel("Resultado parcial")
                        .help("Resultado parcial: no se pudo calcular el tamaño de todo el contenido. Consulta Incidencias para ver las causas.")
                }
            }
            .padding(.vertical, 3).padding(.horizontal, 6)
            .foregroundStyle(entry.id == current ? Color.white : Color.primary)
            .background(entry.id == current ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(entry.partial ? "Resultado parcial: no se pudo calcular el tamaño de todo el contenido. Consulta Incidencias para ver las causas.\n\(entry.id.path)" : entry.id.path)
        .contextMenu {
            Button("Abrir") { open(entry) }
            Button("Analizar") { analyze(entry) }
            Button("Mostrar en Finder") { showInFinder(entry) }
            Button("Abrir en Terminal") { openTerminal(entry) }
            Button("Propiedades") { showProperties(entry) }
        }
    }

    var body: some View {
        let children = entry.children.filter { $0.directory && (showHidden || !$0.id.lastPathComponent.hasPrefix(".")) }
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                if children.isEmpty {
                    Color.clear.frame(width: 16, height: 20).accessibilityHidden(true)
                } else {
                    Button { isExpanded.toggle() } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(isExpanded ? "Contraer" : "Expandir") \(entry.id.lastPathComponent)")
                }
                row
            }
            if isExpanded {
                ForEach(children) { child in
                    DirectoryTree(entry: child, current: current, showHidden: showHidden, open: open, analyze: analyze, showInFinder: showInFinder, openTerminal: openTerminal, showProperties: showProperties)
                        .padding(.leading, 16)
                }
            }
        }
        .onAppear { if isRoot { isExpanded = true } }
    }
}
