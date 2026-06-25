// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HoscIsland",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "HoscIsland",
            path: "Sources/HoscIsland"
        )
    ]
)
