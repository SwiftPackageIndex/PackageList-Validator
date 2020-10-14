// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "validator",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(name: "async-http-client",
                 url: "https://github.com/swift-server/async-http-client.git", from: "1.2.0"),
        .package(name: "swift-argument-parser",
                 url: "https://github.com/apple/swift-argument-parser", from: "0.2.0"),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.3.0"),
        .package(name: "Tagged",
                 url: "https://github.com/pointfreeco/swift-tagged.git", from: "0.5.0"),
    ],
    targets: [
        .target(name: "validator", dependencies: ["ValidatorCore"]),
        .target(
            name: "ValidatorCore",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "ShellOut",
                "Tagged",
            ]),
        .testTarget(name: "ValidatorTests", dependencies: ["ValidatorCore"]),
    ]
)
