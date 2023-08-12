// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import XCTest

import AsyncHTTPClient
import Foundation
import NIO
@testable import ValidatorCore


final class ValidatorTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        Current = .mock
    }

    func test_mergingWithExisting() throws {
        XCTAssertEqual(["a"].asURLs.mergingWithExisting(urls: ["a"].asURLs)
                        .map(\.absoluteString), ["a"])
        XCTAssertEqual(["a"].asURLs.mergingWithExisting(urls: ["A"].asURLs)
                        .map(\.absoluteString), ["A"])
        XCTAssertEqual(["A"].asURLs.mergingWithExisting(urls: ["a"].asURLs)
                        .map(\.absoluteString), ["a"])
        XCTAssertEqual(["a", "A"].asURLs.mergingWithExisting(urls: ["A"].asURLs)
                        .map(\.absoluteString), ["A"])
        XCTAssertEqual(["A", "a", "A"].asURLs.mergingWithExisting(urls: ["A"].asURLs)
                        .map(\.absoluteString), ["A"])
        XCTAssertEqual(["A", "a", "A"].asURLs.mergingWithExisting(urls: ["a"].asURLs)
                        .map(\.absoluteString), ["a"])
    }

    func test_Github_packageList() throws {
        XCTAssertFalse(try Github.packageList().isEmpty)
    }

    func test_appendingGitExtension() throws {
        let s = "https://github.com/weichsel/ZIPFoundation/"
        XCTAssertEqual(PackageURL(rawValue: URL(string: s)!).appendingGitExtension().absoluteString,
                       "https://github.com/weichsel/ZIPFoundation.git")
    }

    func test_Package_decode() throws {
        let data = try fixtureData(for: "arena-package-dump.json")
        let pkg = try JSONDecoder().decode(Package.self, from: data)
        XCTAssertEqual(pkg.dependencies.count, 6)
        XCTAssertEqual(
            pkg.dependencies.first?.firstRemote?.absoluteString,
            "https://github.com/apple/swift-argument-parser"
        )
    }

    func test_PackageURL_owner_repository() throws {
        do {
            let p = PackageURL.init(argument: "https://github.com/stephencelis/SQLite.swift.git")
            XCTAssertEqual(p?.owner, "stephencelis")
            XCTAssertEqual(p?.repository, "SQLite.swift")
        }
        do {
            let p = PackageURL.init(argument: "https://github.com/stephencelis/SQLite.swift")
            XCTAssertEqual(p?.owner, "stephencelis")
            XCTAssertEqual(p?.repository, "SQLite.swift")
        }
    }

    func test_getManifestURL() throws {
        // setup
        let pkgURL = PackageURL(argument: "https://github.com/foo/bar")!
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { try? client.syncShutdown() }

        // MUT
        let url = try Package.getManifestURL(client: client,
                                             packageURL: pkgURL).wait()

        // validate
        XCTAssertEqual(url,
                       .init("https://raw.githubusercontent.com/foo/bar/main/Package.swift"))
    }

    func test_findDependencies() throws {
        // Basic findDependencies test
        // setup
        Current.decodeManifest = { url in .init(
            name: "bar",
            products: [
                .init(name: "prod")
            ],
            dependencies: [
                .init(location: PackageURL(argument: "https://github.com/dep/A")!)
            ]) }

        // MUT
        let url = PackageURL(argument: "https://github.com/foo/bar")!
        let urls = try findDependencies(packageURL: url, waitIfRateLimited: false, retries: 0)

        // validate
        XCTAssertEqual(urls,
                       [PackageURL(argument: "https://github.com/dep/A.git")!])
    }

    func test_expandDependencies() throws {
        // Test case preservation when dependencies are package list item. For instance:
        // A -> dependencies x, y
        // B -> dependencies z, a
        // this will expand into [A, x, y, B, z, a] before uniquing and sorting.
        // We want to avoid uniquing [A, a] into [a] and this is what this test is
        // about

        // setup
        let A = PackageURL(argument: "https://github.com/foo/A.git")!
        let B = PackageURL(argument: "https://github.com/foo/B.git")!
        let x = PackageURL(argument: "https://github.com/foo/x.git")!
        let y = PackageURL(argument: "https://github.com/foo/y.git")!
        let z = PackageURL(argument: "https://github.com/foo/z.git")!
        let a = PackageURL(argument: "https://github.com/foo/a.git")!
        Current.decodeManifest = { url in
            switch url {
                case .init("https://raw.githubusercontent.com/foo/A/main/Package.swift"):
                    return .mock(dependencyURLs: [x, y])
                case .init("https://raw.githubusercontent.com/foo/B/main/Package.swift"):
                    return .mock(dependencyURLs: [z, a])
                default:
                    return .mock(dependencyURLs: [])
            }
        }

        // MUT
        let urls = expandDependencies(inputURLs: [A, B], retries: 0)

        // validate
        XCTAssertEqual(urls, [A, B, x, y, z])
    }

    func test_expandDependencies_normalising() throws {
        // Ensure dependency URLs are properly normalised and case preserving
        // setup
        let A = PackageURL(argument: "https://github.com/foo/A.git")!
        let B = PackageURL(argument: "https://github.com/foo/B.git")!
        let x = PackageURL(argument: "https://github.com/foo/x")!
        let Y = PackageURL(argument: "https://github.com/foo/Y")!
        let z = PackageURL(argument: "https://github.com/foo/z")!
        let a = PackageURL(argument: "https://github.com/foo/a")!
        let x_git = PackageURL(argument: "https://github.com/foo/x.git")!
        let Y_git = PackageURL(argument: "https://github.com/foo/Y.git")!
        let z_git = PackageURL(argument: "https://github.com/foo/z.git")!
        Current.decodeManifest = { url in
            switch url {
                case .init("https://raw.githubusercontent.com/foo/A/main/Package.swift"):
                    return .mock(dependencyURLs: [x, Y])
                case .init("https://raw.githubusercontent.com/foo/B/main/Package.swift"):
                    return .mock(dependencyURLs: [z, a])
                default:
                    return .mock(dependencyURLs: [])
            }
        }

        // MUT
        let urls = expandDependencies(inputURLs: [A, B], retries: 0)

        // validate
        XCTAssertEqual(urls, [A, B, x_git, Y_git, z_git])
    }


    func test_ArraySlice_chunk() throws {
        do {
            XCTAssertEqual(Array(0..<8)[...].chunk(index: 0, of: 3), [0, 1, 2])
            XCTAssertEqual(Array(0..<8)[...].chunk(index: 1, of: 3), [3, 4, 5])
            XCTAssertEqual(Array(0..<8)[...].chunk(index: 2, of: 3), [6, 7])
        }
        do {
            XCTAssertEqual(Array(1..<8)[...].chunk(index: 0, of: 3), [1, 2, 3])
            XCTAssertEqual(Array(1..<8)[...].chunk(index: 1, of: 3), [4, 5, 6])
            XCTAssertEqual(Array(1..<8)[...].chunk(index: 2, of: 3), [7])
        }
        do {
            XCTAssertEqual(Array(0..<2)[...].chunk(index: 0, of: 0), [0, 1])
        }
        do {
            XCTAssertEqual(Array(0..<2)[...].chunk(index: nil, of: 0), [0, 1])
        }
        do {
            XCTAssertEqual(Array(0..<2)[...].chunk(index: 0, of: nil), [0, 1])
        }
        do {
            XCTAssertEqual(Array(0..<2)[...].chunk(index: nil, of: nil), [0, 1])
        }
    }

    func test_CaseinsensitiveHash() throws {
        let a = CaseinsensitiveString(value: "a")
        let A = CaseinsensitiveString(value: "A")
        XCTAssertEqual(a, A)
        XCTAssertEqual(Set([a]).union(Set([A])), Set([a]))
        XCTAssertEqual(Set([A]).union(Set([a])), Set([A]))
    }

    func test_Merge_sorting() throws {
        // Ensure results after merging are sorted
        XCTAssertEqual(MergeLists.merge(["b", "a2"], ["c", "A1"]), ["A1", "a2", "b", "c"])
        XCTAssertEqual(MergeLists.merge(["b", "A2"], ["c", "a1"]), ["a1", "A2", "b", "c"])
        // Ensure sorting ignores case
        XCTAssertEqual(MergeLists.merge(["Ac"], ["ab"]), ["ab", "Ac"])
        XCTAssertEqual(MergeLists.merge(["ac"], ["Ab"]), ["Ab", "ac"])
        // Ensure results are unique (first occurence wins)
        XCTAssertEqual(MergeLists.merge(["b", "a"], ["c", "A"]), ["a", "b", "c"])
        XCTAssertEqual(MergeLists.merge(["b", "A"], ["c", "a"]), ["A", "b", "c"])
    }

}
