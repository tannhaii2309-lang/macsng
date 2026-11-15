// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SngTrans",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "SngTrans", path: "Sources/SngTrans")
    ]
)
