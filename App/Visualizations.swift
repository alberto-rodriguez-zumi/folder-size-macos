import SwiftUI

struct VisualExplorer: View {
    let root: Entry
    let radial: Bool
    let showHidden: Bool
    let minimum: Int64
    let select: (Entry) -> Void
    let open: (Entry) -> Void

    func visible(_ entry: Entry) -> [Entry] {
        entry.children.filter { (showHidden || !$0.id.lastPathComponent.hasPrefix(".")) && (!$0.directory || $0.size >= minimum) && $0.size > 0 }
    }

    var body: some View {
        GeometryReader { geometry in
            if radial {
                ZStack { radialChildren(root, start: 0, end: 360, depth: 0, dimension: min(geometry.size.width, geometry.size.height)) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                tiles(root, depth: 0).frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    func tiles(_ entry: Entry, depth: Int) -> AnyView {
        let children = visible(entry)
        return AnyView(GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(hue: Double((depth * 47 + abs(entry.id.path.hashValue % 60)) % 360) / 360, saturation: 0.35, brightness: 0.82)).overlay(Rectangle().stroke(.background, lineWidth: 1))
                if children.isEmpty || depth >= 5 {
                    Text(entry.id.lastPathComponent).font(.caption).lineLimit(2).padding(4)
                } else {
                    let total = max(1, entry.size)
                    let horizontal = geometry.size.width >= geometry.size.height
                    let length = horizontal ? geometry.size.width : geometry.size.height
                    let _ = total
                    ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                        let offset = children.prefix(index).reduce(Int64(0)) { $0 + $1.size }
                        let fraction = CGFloat(child.size) / CGFloat(total)
                        tiles(child, depth: depth + 1)
                            .frame(width: horizontal ? max(0, length * fraction) : geometry.size.width, height: horizontal ? geometry.size.height : max(0, length * fraction))
                            .offset(x: horizontal ? length * CGFloat(offset) / CGFloat(total) : 0, y: horizontal ? 0 : length * CGFloat(offset) / CGFloat(total))
                    }
                }
            }.contentShape(Rectangle()).onTapGesture(count: 2) { open(entry) }.onTapGesture { select(entry) }.contextMenu { if entry.directory { Button("Abrir") { open(entry) } } }
        }.clipped())
    }

    func radialChildren(_ entry: Entry, start: Double, end: Double, depth: Int, dimension: CGFloat) -> AnyView {
        let children = visible(entry)
        return AnyView(ZStack {
            if depth < 6 {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    let prior = children.prefix(index).reduce(Int64(0)) { $0 + $1.size }
                    let total = max(1, entry.size)
                    let a = start + (end - start) * Double(prior) / Double(total)
                    let b = a + (end - start) * Double(child.size) / Double(total)
                    RingSegment(start: a, end: b, inner: CGFloat(depth + 1) / 7, outer: CGFloat(depth + 2) / 7)
                        .fill(Color(hue: Double((depth * 47 + abs(child.id.path.hashValue % 60)) % 360) / 360, saturation: 0.55, brightness: 0.8))
                        .overlay(RingSegment(start: a, end: b, inner: CGFloat(depth + 1) / 7, outer: CGFloat(depth + 2) / 7).stroke(.background, lineWidth: 0.5))
                        .contentShape(RingSegment(start: a, end: b, inner: CGFloat(depth + 1) / 7, outer: CGFloat(depth + 2) / 7))
                        .onTapGesture(count: 2) { open(child) }.onTapGesture { select(child) }
                        .contextMenu { if child.directory { Button("Abrir") { open(child) } } }
                        .help(child.id.lastPathComponent + " · " + ByteCountFormatter.string(fromByteCount: child.size, countStyle: .file))
                    radialChildren(child, start: a, end: b, depth: depth + 1, dimension: dimension)
                }
            }
        }.frame(width: dimension, height: dimension))
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
