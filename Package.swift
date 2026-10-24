// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "Emmental",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(name: "Emmental", path: "Sources/Emmental"),
    ]
)
