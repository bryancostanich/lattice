// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Lattice",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Lattice",
            path: "Sources/Lattice",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
