// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "SemanticVersion",
    products: [
        .library(
            name: "SemanticVersion",
            targets: ["SemanticVersion"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "SemanticVersion",
                dependencies: [],
                resources: [.process("Documentation.docc")]),
        .testTarget(name: "SemanticVersionTests", dependencies: ["SemanticVersion"]),
    ]
)