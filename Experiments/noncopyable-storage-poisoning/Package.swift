// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "noncopyable-storage-poisoning",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "noncopyable-storage-poisoning")
    ]
)
