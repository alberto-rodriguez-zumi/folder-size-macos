import SwiftUI

private struct EntryMetadata {
    var created: Date?
    var modified: Date?
    var logicalSize: Int?
    var error: String?
}

struct EntryPropertiesView: View {
    @AppStorage(AppLanguage.preferenceKey) private var preferredLanguage = AppLanguage.automatic
    let entry: Entry
    @Environment(\.dismiss) private var dismiss
    @State private var metadata: EntryMetadata?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: entry.directory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 32)).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.id.lastPathComponent.isEmpty ? "/" : entry.id.lastPathComponent)
                        .font(.title3.weight(.semibold)).lineLimit(2)
                    Text(entry.directory ? L("Carpeta") : L("Archivo")).foregroundStyle(.secondary)
                }
            }
            Form {
                LabeledContent(L("Ruta")) {
                    Text(entry.id.path).textSelection(.enabled).lineLimit(3).truncationMode(.middle)
                }
                LabeledContent(L("Tamaño analizado")) {
                    Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file) + (entry.partial ? L(" · parcial") : ""))
                }
                if let metadata {
                    if let logicalSize = metadata.logicalSize, !entry.directory {
                        LabeledContent(L("Tamaño lógico"), value: ByteCountFormatter.string(fromByteCount: Int64(logicalSize), countStyle: .file))
                    }
                    if let created = metadata.created {
                        LabeledContent(L("Creación"), value: created.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let modified = metadata.modified {
                        LabeledContent(L("Modificación"), value: modified.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let error = metadata.error {
                        Text(error).foregroundStyle(.secondary).font(.caption)
                    }
                } else {
                    ProgressView().controlSize(.small)
                }
            }.formStyle(.grouped)
            HStack {
                Spacer()
                Button(L("Cerrar"), systemImage: "xmark") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520, height: 380)
        .task {
            let url = entry.id
            metadata = await Task.detached(priority: .utility) {
                do {
                    let values = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey])
                    return EntryMetadata(created: values.creationDate, modified: values.contentModificationDate, logicalSize: values.fileSize)
                } catch {
                    return EntryMetadata(error: LF("No se pudieron consultar los metadatos: %@", error.localizedDescription))
                }
            }.value
        }
    }
}
