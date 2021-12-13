// swift-tools-version:5.3

// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
        .package(name: "swift-tagged",
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
                .product(name: "Tagged", package: "swift-tagged")
            ]),
        .testTarget(name: "ValidatorTests",
                    dependencies: ["ValidatorCore"],
                    exclude: ["Fixtures"]),
    ]
)
