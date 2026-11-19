import SwiftUI
import AppKit

@main
struct FolderSizeApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
            .defaultSize(width: 1050, height: 700)
    }
}

struct Entry: Identifiable {
    let id: URL
    let directory: Bool
    var size: Int64
    var children: [Entry]
    var partial: Bool
}

@MainActor
final class ScanState: ObservableObject {
    @Published var root: Entry?
    @Published var path: [URL] = []
    @Published var selected: URL?
    @Published var progress = ""
    @Published var issues: [String] = []
    @Published var scanning = false
    @Published var error: String?
    private var task: Task<Void, Never>?
    private var activeScan: UUID?

    var current: Entry? {
        guard var entry = root else { return nil }
        for url in path.dropFirst() {
            guard let child = entry.children.first(where: { $0.id == url }) else { break }
            entry = child
        }
        return entry
    }

    var selectedEntry: Entry? {
        func find(_ entry: Entry) -> Entry? {
            if entry.id == selected { return entry }
            for child in entry.children { if let match = find(child) { return match } }
            return nil
        }
        return current.flatMap(find)
    }

    func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url { scan(url) }
    }

    func scan(_ url: URL) {
        task?.cancel()
        root = nil
        issues = []
        path = [url]
        selected = nil
        scanning = true
        progress = url.path
        let scanID = UUID()
        activeScan = scanID
        task = Task {
            let worker = Task.detached(priority: .utility) { () -> (Entry?, [String]) in
                var problems: [String] = []
                var seen = Set<String>()
                var lastUpdate = Date.distantPast
                let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileSizeKey, .volumeIdentifierKey, .fileResourceIdentifierKey]
                let rootVolume = try? url.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
                func walk(_ item: URL) -> Entry? {
                    if Task.isCancelled { return nil }
                    do {
                        let values = try item.resourceValues(forKeys: keys)
                        if values.isSymbolicLink == true { return Entry(id: item, directory: false, size: 0, children: [], partial: false) }
                        if let rootVolume, let volume = values.volumeIdentifier, !rootVolume.isEqual(volume) { return nil }
                        let directory = values.isDirectory == true
                        var children: [Entry] = []
                        var partial = false
                        var size: Int64 = 0
                        if directory {
                            if Date().timeIntervalSince(lastUpdate) >= 0.2 {
                                lastUpdate = Date()
                                let currentPath = item.path
                                Task { @MainActor in
                                    if self.activeScan == scanID { self.progress = currentPath }
                                }
                            }
                            do {
                                let urls = try FileManager.default.contentsOfDirectory(at: item, includingPropertiesForKeys: Array(keys))
                                for child in urls {
                                    if let node = walk(child) { children.append(node); size += node.size; partial = partial || node.partial }
                                }
                            } catch { problems.append("\(item.path): \(error.localizedDescription)"); partial = true }
                        } else {
                            if let identifier = values.fileResourceIdentifier {
                                let key = "\(String(describing: values.volumeIdentifier)):\(identifier)"
                                if seen.contains(key) { return Entry(id: item, directory: false, size: 0, children: [], partial: false) }
                                seen.insert(key)
                            }
                            if let allocated = values.totalFileAllocatedSize { size = Int64(allocated) }
                            else { partial = true; problems.append("\(item.path): tamaño asignado no disponible") }
                        }
                        return Entry(id: item, directory: directory, size: size, children: children.sorted { $0.size > $1.size }, partial: partial)
                    } catch { problems.append("\(item.path): \(error.localizedDescription)"); return Entry(id: item, directory: false, size: 0, children: [], partial: true) }
                }
                return (walk(url), problems)
            }
            let result = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            guard !Task.isCancelled else { return }
            root = result.0
            issues = result.1
            scanning = false
            activeScan = nil
        }
    }

    func cancel() { activeScan = nil; task?.cancel(); scanning = false; progress = "" }
    func open(_ entry: Entry) { if entry.directory { path.append(entry.id); selected = nil } }
    func navigate(_ entry: Entry) {
        guard entry.directory, let root else { return }
        var chain: [URL] = []
        func find(_ node: Entry) -> Bool {
            chain.append(node.id)
            if node.id == entry.id { return true }
            for child in node.children where child.directory { if find(child) { return true } }
            chain.removeLast()
            return false
        }
        if find(root) { path = chain; selected = nil }
    }
    func trash(_ entry: Entry) {
        let alert = NSAlert()
        alert.messageText = "¿Mover a la papelera?"
        alert.informativeText = "\(entry.id.path)\n\(entry.directory ? "Se moverá la carpeta y todo su contenido." : "")"
        alert.addButton(withTitle: "Cancelar")
        alert.addButton(withTitle: "Mover a la papelera")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do { try FileManager.default.trashItem(at: entry.id, resultingItemURL: nil); if let root { scan(root.id) } }
        catch { self.error = error.localizedDescription }
    }
}

struct ContentView: View {
    @StateObject private var state = ScanState()
    @State private var showTree = true
    @State private var showHidden = false
    @State private var filterSmall = false
    @State private var minimumMB = 10.0
    @State private var radial = false
    private func size(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .file) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Elegir carpeta o volumen", action: state.choose)
                if state.scanning { ProgressView().controlSize(.small); Text("Analizando…"); Button("Cancelar", action: state.cancel) }
                Spacer()
                if let root = state.root { Button("Analizar de nuevo") { state.scan(root.id) } }
            }
            if state.scanning {
                Text(state.progress).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).frame(maxWidth: .infinity, alignment: .leading)
            }
            if let current = state.current {
                HStack {
                    ForEach(Array(state.path.enumerated()), id: \.offset) { index, url in
                        Button(url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent) { state.path = Array(state.path.prefix(index + 1)); state.selected = nil }.buttonStyle(.link)
                        if index < state.path.count - 1 { Text("/").foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Text("\(size(current.size))\(current.partial ? " · parcial" : "")")
                }
                HStack {
                    Toggle("Árbol", isOn: $showTree)
                    Toggle("Mostrar ocultos", isOn: $showHidden)
                    Toggle("Ocultar carpetas menores de", isOn: $filterSmall)
                    TextField("MB", value: $minimumMB, format: .number).frame(width: 60).disabled(!filterSmall)
                    Text("MB")
                    Spacer()
                    Picker("Vista", selection: $radial) { Text("Mosaico").tag(false); Text("Radial").tag(true) }.pickerStyle(.segmented).frame(width: 180)
                }
                HStack(alignment: .top) {
                    if showTree, let root = state.root {
                        ScrollView { DirectoryTree(entry: root, showHidden: showHidden, open: state.navigate).frame(maxWidth: .infinity, alignment: .leading) }.frame(width: 220)
                        Divider()
                    }
                    VisualExplorer(root: current, radial: radial, showHidden: showHidden, minimum: filterSmall ? Int64(max(0, min(minimumMB, 1_000_000)) * 1_000_000) : 0, select: { state.selected = $0.id }, open: state.navigate)
                }.frame(minHeight: 260, maxHeight: .infinity)
                List(selection: $state.selected) {
                    ForEach(current.children.filter { (showHidden || !$0.id.lastPathComponent.hasPrefix(".")) && (!filterSmall || !$0.directory || Double($0.size) >= minimumMB * 1_000_000) }) { entry in
                        HStack {
                            Image(systemName: entry.directory ? "folder.fill" : "doc")
                            Text(entry.id.lastPathComponent)
                            Spacer()
                            Text(size(entry.size) + (entry.partial ? " · parcial" : "")).monospacedDigit()
                            if entry.directory { Button("Abrir") { state.open(entry) }.buttonStyle(.borderless) }
                        }.tag(entry.id)
                    }
                }
                if let selected = state.selectedEntry, selected.id != current.id {
                    Text(selected.id.path).textSelection(.enabled).lineLimit(2)
                    HStack {
                        Button("Mostrar en Finder") { NSWorkspace.shared.activateFileViewerSelecting([selected.id]) }
                        Button("Abrir en Terminal") { NSWorkspace.shared.open([selected.directory ? selected.id : selected.id.deletingLastPathComponent()], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), configuration: NSWorkspace.OpenConfiguration()) }
                        Button("Copiar ruta") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(selected.id.path, forType: .string) }
                        Spacer()
                        Button("Mover a la papelera…") { state.trash(selected) }
                    }
                }
                if !state.issues.isEmpty { DisclosureGroup("\(state.issues.count) incidencias") { ScrollView { Text(state.issues.joined(separator: "\n")).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 120) } }
            } else if !state.scanning { Spacer(); Text("Selecciona una carpeta o un volumen para analizar su espacio.").foregroundStyle(.secondary).frame(maxWidth: .infinity); Spacer() }
        }.padding().alert("No se ha podido completar la acción", isPresented: Binding(get: { state.error != nil }, set: { if !$0 { state.error = nil } })) { Button("Aceptar") { state.error = nil } } message: { Text(state.error ?? "") }
    }
}
