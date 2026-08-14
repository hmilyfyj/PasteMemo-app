// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PasteMemo",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(
            url: "https://github.com/lifedever/PermissionFlow.git",
            from: "0.1.0"
        ),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1"),
    ],
    targets: [
        .executableTarget(
            name: "PasteMemo",
            dependencies: [
                .product(name: "PermissionFlow", package: "PermissionFlow"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources",
            exclude: ["MCPProxy"],
            resources: [
                .process("Localization"),
                .copy("Resources"),
            ]
        ),
        .executableTarget(
            name: "pastememo-mcp",
            path: "Sources/MCPProxy"
        ),
        .testTarget(
            name: "PasteMemoTests",
            dependencies: ["PasteMemo"],
            path: "Tests"
        ),
    ]
)
