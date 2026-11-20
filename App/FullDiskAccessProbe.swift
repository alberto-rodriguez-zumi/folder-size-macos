import Darwin

enum FullDiskAccessProbe {
    // macOS has no API for querying Full Disk Access. Opening this protected
    // file is only an indication of access; failures leave the help visible.
    static func canOpenProtectedFile(at path: String = "/Library/Application Support/com.apple.TCC/TCC.db") -> Bool {
        let descriptor = open(path, O_RDONLY | O_CLOEXEC)
        guard descriptor >= 0 else { return false }
        close(descriptor)
        return true
    }
}
