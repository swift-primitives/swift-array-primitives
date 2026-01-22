// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "noncopyable-multifile-poisoning",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "noncopyable-multifile-poisoning")
    ]
)
