// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickSnip",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "QuickSnip",
            path: "Sources/QuickSnip"
        )
    ]
)
