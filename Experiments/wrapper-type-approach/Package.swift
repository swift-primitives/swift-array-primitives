// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "wrapper-type-approach",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "wrapper-type-approach",
            path: "Sources/wrapper-type-approach"
        ),
    ],
    swiftLanguageModes: [.v6]
)
