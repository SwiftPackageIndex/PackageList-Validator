// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "validator",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(name: "swift-argument-parser",
                 url: "https://github.com/apple/swift-argument-parser", from: "0.2.0"),
    ],
    targets: [
        .target(name: "validator", dependencies: ["ValidatorCore"]),
        .target(
            name: "ValidatorCore",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .testTarget(name: "ValidatorTests", dependencies: ["ValidatorCore"]),
    ]
)
