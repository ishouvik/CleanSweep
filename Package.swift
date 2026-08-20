// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CleanSweep",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CleanSweep", targets: ["CleanSweep"])
    ],
    targets: [
        .executableTarget(
            name: "CleanSweep",
            path: "Sources/CleanSweep",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
