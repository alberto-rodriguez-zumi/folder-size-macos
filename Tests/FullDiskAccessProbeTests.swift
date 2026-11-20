import Foundation

@main
struct FullDiskAccessProbeTests {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("probe")
        precondition(!FullDiskAccessProbe.canOpenProtectedFile(at: file.path))
        try Data().write(to: file)
        precondition(FullDiskAccessProbe.canOpenProtectedFile(at: file.path))
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)
        precondition(!FullDiskAccessProbe.canOpenProtectedFile(at: file.path))
        print("Full Disk Access probe checks passed")
    }
}
