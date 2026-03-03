// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LogKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "LogKit",
            targets: ["LogKit"]
        )
    ],
    targets: [
        .target(
            name: "LogKit",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "LogKitTests",
            dependencies: ["LogKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
