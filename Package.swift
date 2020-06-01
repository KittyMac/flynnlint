// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "FlynnLint",
    products: [
        .executable(name: "flynnlint", targets: ["flynnlint"]),
        .library(name: "FlynnLintFramework", targets: ["FlynnLintFramework"])
    ],
    dependencies: [
		.package(url: "https://github.com/KittyMac/Flynn.git", from: "0.0.0"),
        .package(url: "https://github.com/Carthage/Commandant.git", .upToNextMinor(from: "0.17.0")),
        .package(url: "https://github.com/jpsim/SourceKitten.git", .upToNextMinor(from: "0.29.0")),
        .package(url: "https://github.com/jpsim/Yams.git", from: "2.0.0"),
        .package(url: "https://github.com/scottrhoyt/SwiftyTextTable.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "flynnlint",
            dependencies: [
                "Commandant",
                "FlynnLintFramework",
                "SwiftyTextTable",
                "Flynn",
            ]
        ),
        .target(
            name: "FlynnLintFramework",
            dependencies: [
                "SourceKittenFramework",
                "Yams",
                "Flynn",
            ]
        ),
        .testTarget(
            name: "FlynnLintFrameworkTests",
            dependencies: [
                "FlynnLintFramework"
            ],
            exclude: [
                "Resources",
            ]
        )
    ]
)
