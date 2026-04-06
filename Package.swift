// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PasteMemo",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1"),
    ],
    targets: [
        .executableTarget(
            name: "PasteMemo",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources",
            resources: [
                .process("Localization"),
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "PasteMemoTests",
            dependencies: ["PasteMemo"],
            path: "Tests"
        ),
    ]
)
