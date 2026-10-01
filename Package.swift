// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Pomo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pomo", targets: ["Pomo"])
    ],
    targets: [
        .executableTarget(
            name: "Pomo",
            path: "Sources/Pomo"
        ),
        .testTarget(name: "PomoTests", dependencies: ["Pomo"])
    ]
)
