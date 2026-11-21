import SwiftUI
import AppKit
import Darwin

@main
struct FolderSizeApp: App {
    @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.automatic
    var body: some Scene {
        WindowGroup { LocalizedContent { ContentView() } }
            .defaultSize(width: 900, height: 650)
            .commands { AboutCommand() }
        Window(L("Acerca de Folder Size"), id: "about") {
            LocalizedContent { AboutView() }
        }
        .windowResizability(.contentSize)
        Window(L("Configuración"), id: "settings") {
            LocalizedContent { LanguageSettingsView() }
        }
        .windowResizability(.contentSize)
    }
}

struct AboutCommand: Commands {
    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.automatic

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(L("Acerca de Folder Size")) { openWindow(id: "about") }
        }
        CommandGroup(replacing: .appSettings) {
            Button(L("Configuración") + "…", systemImage: "globe") { openWindow(id: "settings") }.keyboardShortcut(",")
        }
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
    @Published var volumeCapacity: VolumeCapacity?
    private var task: Task<Void, Never>?
    private var activeScan: UUID?
    private var volumeRequest: UUID?

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
            volumeCapacity = nil
            let request = UUID()
            volumeRequest = request
            Task {
                let capacity = await Task.detached(priority: .utility) { VolumeCapacity.read(at: url) }.value
                if volumeRequest == request { volumeCapacity = capacity }
            }
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
                            else { partial = true; problems.append("\(item.path): \(L("tamaño asignado no disponible"))") }
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

    func cancel() { activeScan = nil; task?.cancel(); scanning = false; progress = ""; if root == nil { volumeRequest = nil } }
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
        alert.messageText = L("¿Mover a la papelera?")
        alert.informativeText = "\(entry.id.path)\n\(entry.directory ? L("Se moverá la carpeta y todo su contenido.") : "")"
        alert.addButton(withTitle: L("Cancelar"))
        alert.addButton(withTitle: L("Mover a la papelera"))
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do { try FileManager.default.trashItem(at: entry.id, resultingItemURL: nil); if let root { scan(root.id) } }
        catch { self.error = error.localizedDescription }
    }
}

struct ContentView: View {
    @AppStorage(AppLanguage.preferenceKey) private var preferredLanguage = AppLanguage.automatic
    @StateObject private var state = ScanState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showTree = true
    @State private var treeWidth: CGFloat = 250
    @State private var showHidden = false
    @State private var filterSmall = false
    @State private var minimumMB = 10.0
    @State private var radial = false
    @State private var displayDepth = 3
    @State private var resultsSort = ResultsSort()
    private func size(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .file) }
    private var minimumBytes: Int64 {
        guard filterSmall else { return 0 }
        return Int64(max(0, min(minimumMB, 1_000_000)) * 1_000_000)
    }
    private func chart(_ current: Entry) -> some View {
        VisualExplorer(root: current, scanRoot: state.root?.id ?? current.id, radial: radial, showHidden: showHidden, minimum: minimumBytes, maxDepth: displayDepth, select: { state.selected = $0.id }, open: state.navigate, analyze: state.analyze, showInFinder: state.showInFinder, openTerminal: state.openTerminal, showProperties: { state.propertyEntry = $0 })
    }
    private func sortHeader(_ title: String, column: ResultsSort.Column) -> some View {
        Button {
            resultsSort.select(column)
        } label: {
            HStack(spacing: 4) {
                Text(L(title))
                if resultsSort.column == column {
                    Image(systemName: resultsSort.ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(LF("Ordenar por %@", L(title).lowercased()))
        .accessibilityLabel(LF("Ordenar por %@", L(title).lowercased()))
        .accessibilityValue(resultsSort.column == column ? (resultsSort.ascending ? L("Ascendente") : L("Descendente")) : L("Sin ordenar"))
    }
    var body: some View {
      Group {
       if state.root == nil {
        ScanStartView(state: state, displayDepth: $displayDepth)
       } else {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(L("Elegir carpeta o volumen"), systemImage: "folder", action: state.choose)
                if state.scanning { ProgressView().controlSize(.small); Text(L("Analizando…")); Button(L("Cancelar"), systemImage: "xmark", action: state.cancel) }
                Spacer()
                if let root = state.root { Button(L("Analizar de nuevo"), systemImage: "arrow.clockwise") { state.scan(root.id) } }
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
                    .help(L("Subir un nivel"))
                    .accessibilityLabel(L("Subir un nivel"))
                    .keyboardShortcut(.upArrow, modifiers: .command)
                    ForEach(Array(state.path.enumerated()), id: \.offset) { index, url in
                        Button(url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent) { state.path = Array(state.path.prefix(index + 1)); state.selected = nil }.buttonStyle(.link)
                        if index < state.path.count - 1 { Text("/").foregroundStyle(.secondary) }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(size(current.size))\(current.partial ? L(" · parcial") : "")")
                        if let capacity = state.volumeCapacity {
                            let percentage = (Double(capacity.available) / Double(capacity.total)).formatted(.percent.precision(.fractionLength(0...1)))
                            Text(LF("Volumen: %@ total · %@ libre (%@ libre)", size(capacity.total), size(capacity.available), percentage))
                                .font(.caption).foregroundStyle(.secondary)
                            Text(capacity.estimatedReclaimable.map { LF("Recuperable estimado: %@", size($0)) } ?? L("Recuperable estimado: no disponible"))
                                .font(.caption).foregroundStyle(.secondary)
                                .help(L("Estimación calculada como la diferencia entre la capacidad disponible para uso importante y el espacio libre. Puede cambiar y no representa una medición exacta del espacio purgable."))
                        }
                    }
                }
                if current.partial {
                    HStack {
                        Text(L("El análisis tiene resultados parciales por problemas de acceso.")).font(.caption).foregroundStyle(.secondary)
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
                    .help(showTree ? L("Ocultar árbol de carpetas") : L("Mostrar árbol de carpetas"))
                    .accessibilityLabel(showTree ? L("Ocultar árbol de carpetas") : L("Mostrar árbol de carpetas"))
                    Toggle(L("Mostrar ocultos"), isOn: $showHidden)
                        .disabled(!state.includeHiddenFolders)
                        .help(state.includeHiddenFolders ? L("Mostrar u ocultar elementos del análisis") : L("Las carpetas ocultas se excluyeron del análisis"))
                    MinimumFolderSizeControl(isEnabled: $filterSmall, minimumMB: $minimumMB)
                    Picker(L("Niveles"), selection: $displayDepth) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }.frame(width: 95)
                    Spacer()
                    Picker(L("Vista"), selection: $radial) {
                        Image(systemName: "square.grid.2x2.fill").accessibilityLabel(L("Mosaico")).help(L("Mosaico")).tag(false)
                        Image(systemName: "chart.pie.fill").accessibilityLabel("Radial").help("Radial").tag(true)
                    }.labelsHidden().pickerStyle(.segmented).frame(width: 90)
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
                  VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        sortHeader(L("Nombre"), column: .name)
                        Spacer()
                        sortHeader(L("Tamaño"), column: .size)
                            .frame(width: 140, alignment: .trailing)
                        Color.clear.frame(width: 20, height: 1).accessibilityHidden(true)
                        Color.clear.frame(width: 28, height: 1).accessibilityHidden(true)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    Divider()
                  List(selection: $state.selected) {
                    ForEach(resultsSort.sorted(current.children.filter { (showHidden || !$0.id.lastPathComponent.hasPrefix(".")) && (!$0.directory || $0.partial || $0.size >= minimumBytes) }, name: { $0.id.lastPathComponent }, size: { $0.size })) { entry in
                        HStack(spacing: 8) {
                            Image(systemName: entry.directory ? "folder.fill" : "doc")
                            Text(entry.id.lastPathComponent).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(size(entry.size)).monospacedDigit().frame(width: 140, alignment: .trailing)
                            ZStack {
                                Color.clear.accessibilityHidden(true)
                                if entry.partial {
                                    Image(systemName: "exclamationmark.circle")
                                        .accessibilityLabel(L("Resultado parcial"))
                                        .help(L("Resultado parcial: no se pudo calcular el tamaño de todo el contenido. Consulta Incidencias para ver las causas."))
                                }
                            }.frame(width: 20, height: 24)
                            ZStack {
                                Color.clear.accessibilityHidden(true)
                                if entry.directory {
                                    Button { state.open(entry) } label: {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(state.selected == entry.id ? Color.white : Color.accentColor)
                                    .help(L("Abrir carpeta"))
                                    .accessibilityLabel(LF("Abrir carpeta %@", entry.id.lastPathComponent))
                                }
                            }.frame(width: 28, height: 24)
                        }.tag(entry.id)
                            .contextMenu {
                                if entry.directory {
                                    Button(L("Abrir"), systemImage: "folder") { state.navigate(entry) }
                                    Button(L("Analizar"), systemImage: "arrow.clockwise") { state.analyze(entry) }
                                }
                                Button(L("Mostrar en Finder"), systemImage: "folder") { state.showInFinder(entry) }
                                Button(L("Abrir en Terminal"), systemImage: "terminal") { state.openTerminal(entry) }
                                Button(L("Propiedades"), systemImage: "info.circle") { state.propertyEntry = entry }
                            }
                    }
                  }
                  }
                }
                if let selected = state.selectedEntry, selected.id != current.id {
                    Text(selected.id.path).textSelection(.enabled).lineLimit(2)
                    HStack {
                        Button(L("Mostrar en Finder"), systemImage: "folder") { state.showInFinder(selected) }
                        Button(L("Abrir en Terminal"), systemImage: "terminal") { state.openTerminal(selected) }
                        Button(L("Copiar ruta"), systemImage: "doc.on.doc") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(selected.id.path, forType: .string) }
                        Spacer()
                        Button(L("Mover a la papelera…"), systemImage: "trash") { state.trash(selected) }
                    }
                }
                if !state.issues.isEmpty { DisclosureGroup(LF(state.issues.count == 1 ? "%lld incidencia" : "%lld incidencias", Int64(state.issues.count))) { ScrollView { Text(state.issues.joined(separator: "\n")).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 120) } }
            } else if !state.scanning { Spacer(); Text(L("Selecciona una carpeta o un volumen para analizar su espacio.")).foregroundStyle(.secondary).frame(maxWidth: .infinity); Spacer() }
        }.padding().alert(L("No se ha podido completar la acción"), isPresented: Binding(get: { state.error != nil }, set: { if !$0 { state.error = nil } })) { Button(L("Aceptar")) { state.error = nil } } message: { Text(state.error ?? "") }
       }
      }
      .sheet(item: $state.propertyEntry) { entry in
          EntryPropertiesView(entry: entry)
      }
    }
}
