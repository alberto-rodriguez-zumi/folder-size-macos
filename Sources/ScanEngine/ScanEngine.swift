import Foundation

public struct ScanIssue: Sendable {
    public let url: URL
    public let message: String
}

public struct ScanNode: Sendable {
    public let url: URL
    public let isDirectory: Bool
    public let allocatedSize: Int64
    public let logicalSize: Int64
    public let isPartial: Bool
    public let children: [ScanNode]
}

public struct ScanResult: Sendable {
    public let root: ScanNode
    public let issues: [ScanIssue]
}
