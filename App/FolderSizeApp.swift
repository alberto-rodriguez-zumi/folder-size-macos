import SwiftUI
import AppKit
import Darwin

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
    var needsScan: Bool = false
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
    @Published var propertyEntry: Entry?
    @Published var fullDetail = false
    @Published var includeHiddenFolders = true
    @Published var scannedItems = 0
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

    func scan(_ url: URL, expanding: Bool = false) {
        task?.cancel()
        if !expanding {
            root = nil
            issues = []
            path = [url]
        }
        selected = nil
        scanning = true
        scannedItems = 0
        progress = url.path
        let retainFullDetail = fullDetail
        let scanHiddenFolders = includeHiddenFolders
        let scanID = UUID()
        activeScan = scanID
        task = Task {
            let worker = Task.detached(priority: .utility) { () -> (Entry?, [String]) in
                var problems: [String] = []
                var seen = Set<String>()
                var lastUpdate = Date.distantPast
                var itemCount = 0
                let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey, .totalFileAllocatedSizeKey, .fileSizeKey, .volumeIdentifierKey, .fileResourceIdentifierKey]
                let rootVolume = try? url.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
                func walk(_ item: URL, depth: Int = 0) -> Entry? {
                    return autoreleasepool {
                    if Task.isCancelled { return nil }
                    do {
                        let values = try item.resourceValues(forKeys: keys)
                        if values.isSymbolicLink == true { return Entry(id: item, directory: false, size: 0, children: [], partial: false) }
                        if let rootVolume, let volume = values.volumeIdentifier, !rootVolume.isEqual(volume) { return nil }
                        let directory = values.isDirectory == true
                        if depth > 0 && directory && !scanHiddenFolders && (values.isHidden == true || item.lastPathComponent.hasPrefix(".")) { return nil }
                        itemCount += 1
                        var children: [Entry] = []
                        var partial = false
                        var size: Int64 = 0
                        if directory {
                            if Date().timeIntervalSince(lastUpdate) >= 0.2 {
                                lastUpdate = Date()
                                let currentPath = item.path
                                let count = itemCount
                                Task { @MainActor in
                                    if self.activeScan == scanID { self.progress = currentPath; self.scannedItems = count }
                                }
                            }
                            do {
                                let urls = try FileManager.default.contentsOfDirectory(at: item, includingPropertiesForKeys: Array(keys))
                                for child in urls {
                                    if let node = walk(child, depth: depth + 1) { if retainFullDetail || depth < 4 { children.append(node) }; size += node.size; partial = partial || node.partial }
                                }
                            } catch { problems.append("\(item.path): \(error.localizedDescription)"); partial = true }
                        } else {
                            var info = stat()
                            if lstat(item.path, &info) == 0 && info.st_nlink > 1 {
                                let key = "\(info.st_dev):\(info.st_ino)"
                                if seen.contains(key) { return Entry(id: item, directory: false, size: 0, children: [], partial: false) }
                                seen.insert(key)
                            }
                            if let allocated = values.totalFileAllocatedSize { size = Int64(allocated) }
                            else { partial = true; problems.append("\(item.path): tamaño asignado no disponible") }
                        }
                        return Entry(id: item, directory: directory, size: size, children: children.sorted { $0.size > $1.size }, partial: partial, needsScan: directory && !retainFullDetail && depth >= 4)
                    } catch { problems.append("\(item.path): \(error.localizedDescription)"); return Entry(id: item, directory: false, size: 0, children: [], partial: true) }
                    }
                }
                return (walk(url), problems)
            }
            let result = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            guard !Task.isCancelled else { return }
            if expanding, let replacement = result.0, let oldRoot = root {
                let affectedPath = url.standardizedFileURL.path
                let updatedIssues = issues.filter { issue in
                    !issue.hasPrefix(affectedPath + ": ") && !issue.hasPrefix(affectedPath + "/")
                } + result.1
                func replace(_ node: Entry) -> Entry {
                    if node.id == replacement.id { return replacement }
                    guard url.path.hasPrefix(node.id.path.hasSuffix("/") ? node.id.path : node.id.path + "/") else { return node }
                    var updated = node
                    updated.children = node.children.map(replace)
                    updated.size = updated.children.reduce(0) { $0 + $1.size }
                    let nodePath = node.id.standardizedFileURL.path
                    updated.partial = updated.children.contains { $0.partial } || updatedIssues.contains { $0.hasPrefix(nodePath + ": ") }
                    return updated
                }
                root = replace(oldRoot)
                issues = updatedIssues
                var validPath: [URL] = []
                var currentNode = root
                for component in path {
                    guard let node = currentNode, node.id == component else { break }
                    validPath.append(component)
                    let nextIndex = validPath.count
                    currentNode = nextIndex < path.count ? node.children.first { $0.id == path[nextIndex] } : nil
                }
                path = validPath
            } else {
                root = result.0
                issues = result.1
            }
            scanning = false
            activeScan = nil
        }
    }

    func cancel() { activeScan = nil; task?.cancel(); scanning = false; progress = "" }
    func goUp() {
        guard path.count > 1 else { return }
        path.removeLast()
        selected = nil
    }
    func open(_ entry: Entry) { navigate(entry) }
    func showInFinder(_ entry: Entry) {
        NSWorkspace.shared.activateFileViewerSelecting([entry.id])
    }
    func openTerminal(_ entry: Entry) {
        let folder = entry.directory ? entry.id : entry.id.deletingLastPathComponent()
        NSWorkspace.shared.open([folder], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), configuration: NSWorkspace.OpenConfiguration())
    }
    func analyze(_ entry: Entry) {
        guard entry.directory else { return }
        scan(entry.id, expanding: true)
    }
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
        if find(root) { path = chain; selected = nil; if entry.needsScan { scan(entry.id, expanding: true) } }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showTree = true
    @State private var treeWidth: CGFloat = 250
    @State private var showHidden = false
    @State private var filterSmall = false
    @State private var minimumMB = 10.0
    @State private var radial = false
    @State private var displayDepth = 3
    private func size(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .file) }
    private var minimumBytes: Int64 {
        guard filterSmall else { return 0 }
        return Int64(max(0, min(minimumMB, 1_000_000)) * 1_000_000)
    }
    private func chart(_ current: Entry) -> some View {
        VisualExplorer(root: current, scanRoot: state.root?.id ?? current.id, radial: radial, showHidden: showHidden, minimum: minimumBytes, maxDepth: displayDepth, select: { state.selected = $0.id }, open: state.navigate, analyze: state.analyze, showInFinder: state.showInFinder, openTerminal: state.openTerminal, showProperties: { state.propertyEntry = $0 })
    }
    var body: some View {
      Group {
       if state.root == nil {
        ScanStartView(state: state, displayDepth: $displayDepth)
       } else {
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
                    Button(action: state.goUp) {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(state.path.count <= 1)
                    .help("Subir un nivel")
                    .accessibilityLabel("Subir un nivel")
                    .keyboardShortcut(.upArrow, modifiers: .command)
                    ForEach(Array(state.path.enumerated()), id: \.offset) { index, url in
                        Button(url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent) { state.path = Array(state.path.prefix(index + 1)); state.selected = nil }.buttonStyle(.link)
                        if index < state.path.count - 1 { Text("/").foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Text("\(size(current.size))\(current.partial ? " · parcial" : "")")
                }
                if current.partial {
                    HStack {
                        Text("El análisis tiene resultados parciales por problemas de acceso.").font(.caption).foregroundStyle(.secondary)
                        PrivacyAccessHelp()
                    }
                }
                HStack {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                            showTree.toggle()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "sidebar.left")
                            Image(systemName: showTree ? "chevron.left" : "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                    }
                    .help(showTree ? "Ocultar árbol de carpetas" : "Mostrar árbol de carpetas")
                    .accessibilityLabel(showTree ? "Ocultar árbol de carpetas" : "Mostrar árbol de carpetas")
                    Toggle("Mostrar ocultos", isOn: $showHidden)
                        .disabled(!state.includeHiddenFolders)
                        .help(state.includeHiddenFolders ? "Mostrar u ocultar elementos del análisis" : "Las carpetas ocultas se excluyeron del análisis")
                    MinimumFolderSizeControl(isEnabled: $filterSmall, minimumMB: $minimumMB)
                    Picker("Niveles", selection: $displayDepth) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }.frame(width: 95)
                    Spacer()
                    Picker("Vista", selection: $radial) { Text("Mosaico").tag(false); Text("Radial").tag(true) }.labelsHidden().pickerStyle(.segmented).frame(width: 180)
                }
                ResizableResults {
                  if let root = state.root {
                    ResizableSidebar(sidebarWidth: $treeWidth, isVisible: showTree) {
                        ScrollView {
                            DirectoryTree(entry: root, current: current.id, showHidden: showHidden, open: state.navigate, analyze: state.analyze, showInFinder: state.showInFinder, openTerminal: state.openTerminal, showProperties: { state.propertyEntry = $0 }, isRoot: true)
                                .padding(.vertical, 8).padding(.horizontal, 6)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    } content: {
                        chart(current)
                    }
                  }
                } list: {
                  List(selection: $state.selected) {
                    ForEach(current.children.filter { (showHidden || !$0.id.lastPathComponent.hasPrefix(".")) && (!$0.directory || $0.partial || $0.size >= minimumBytes) }) { entry in
                        HStack {
                            Image(systemName: entry.directory ? "folder.fill" : "doc")
                            Text(entry.id.lastPathComponent)
                            Spacer()
                            Text(size(entry.size) + (entry.partial ? " · parcial" : "")).monospacedDigit()
                            if entry.directory { Button("Abrir") { state.open(entry) }.buttonStyle(.borderless) }
                        }.tag(entry.id)
                            .contextMenu {
                                if entry.directory {
                                    Button("Abrir") { state.navigate(entry) }
                                    Button("Analizar") { state.analyze(entry) }
                                }
                                Button("Mostrar en Finder") { state.showInFinder(entry) }
                                Button("Abrir en Terminal") { state.openTerminal(entry) }
                                Button("Propiedades") { state.propertyEntry = entry }
                            }
                    }
                  }
                }
                if let selected = state.selectedEntry, selected.id != current.id {
                    Text(selected.id.path).textSelection(.enabled).lineLimit(2)
                    HStack {
                        Button("Mostrar en Finder") { state.showInFinder(selected) }
                        Button("Abrir en Terminal") { state.openTerminal(selected) }
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
      .sheet(item: $state.propertyEntry) { entry in
          EntryPropertiesView(entry: entry)
      }
    }
}
