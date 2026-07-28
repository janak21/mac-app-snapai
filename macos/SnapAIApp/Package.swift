// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SnapAIApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SnapAIApp",
            targets: ["SnapAIApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SnapAIApp",
            path: "Sources/SnapAIApp"
        ),
        .testTarget(
            name: "SnapAIAppTests",
            dependencies: ["SnapAIApp"],
            path: "Tests/SnapAIAppTests"
        )
    ]
)
