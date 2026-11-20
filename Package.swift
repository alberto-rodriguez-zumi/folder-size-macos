// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FolderSize",
    platforms: [.macOS(.v15)],
    products: [.library(name: "ScanEngine", targets: ["ScanEngine"])],
    targets: [.target(name: "ScanEngine")]
)
