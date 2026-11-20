import Foundation

struct VolumeCapacity: Sendable {
    let total: Int64
    let available: Int64
    let importantAvailable: Int64?

    var estimatedReclaimable: Int64? {
        guard let importantAvailable, available >= 0, available <= total,
              importantAvailable >= available, importantAvailable <= total else { return nil }
        return importantAvailable - available
    }

    static func read(at url: URL) -> VolumeCapacity? {
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
              let total = values.volumeTotalCapacity, total > 0,
              let available = values.volumeAvailableCapacity, available >= 0 else { return nil }
        let important = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
        return VolumeCapacity(total: Int64(total), available: Int64(available), importantAvailable: important)
    }
}

