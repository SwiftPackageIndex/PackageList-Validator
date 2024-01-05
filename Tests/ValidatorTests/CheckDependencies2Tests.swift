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

@testable import ValidatorCore

import CanonicalPackageURL
import NIO


final class CheckDependencies2Tests: XCTestCase {
    var check = CheckDependencies2()

    override func setUp() {
        super.setUp()
        check.apiBaseURL = "unused"
        check.input = nil
        check.limit = .max
        check.spiApiToken = "unused"
        check.output = "unused"
    }

    func test_run_basic() async throws {
        // Input urls and api urls agree - we're up-to-date with reconciliation, i.e. the package list
        // we process in validation is the same package list that has been reconciled when we make the
        // dependencies API call.
        // setup
        Current = .mock
        Current.fetchDependencies = { _ in [
            .init(.p1, dependencies: []),
            .init(.p2, dependencies: [.p3]),
        ]}
        var saved: [PackageURL]? = nil
        Current.fileManager.createFile = { path, data, _ in
            guard path.hasSuffix("package.json") else { return false }
            guard let data = data else {
                XCTFail("data must not be nil")
                return false
            }
            guard let list = try? JSONDecoder().decode([PackageURL].self, from: data) else {
                XCTFail("decoding of output failed")
                return false
            }
            saved = list
            return true
        }
        Current.fetchRepositoryAsync = { _, url in
            if url == PackageURL.p3 {
                return .init(defaultBranch: "main", owner: "org", name: "3")
            } else {
                throw Error.unexpectedCall
            }
        }
        Current.fetch = { client, url in
            // getManifestURL -> Github.listRepositoryFilePaths -> Github.fetch
            guard url.absoluteString == "https://api.github.com/repos/org/3/git/trees/main" else {
                return client.eventLoopGroup.next().makeFailedFuture(Error.unexpectedCall)
            }
            return client.eventLoopGroup.next().makeSucceededFuture(
                ByteBuffer(data: .listRepositoryFilePaths(for: "org/3"))
            )
        }
        var decodeCalled = false
        Current.decodeManifest = { url in
            guard url.absoluteString == "https://raw.githubusercontent.com/org/3/main/Package.swift" else {
                throw Error.unexpectedCall
            }
            decodeCalled = true
            return .init(name: "3", products: [], dependencies: [])
        }
        check.packageUrls = [.p1, .p2]
        check.output = "package.json"

        // MUT
        try await check.run()

        // validate
        XCTAssertEqual(saved, [.p1, .p2, .p3])
        XCTAssertTrue(decodeCalled)
    }

    func test_run_list_newer() async throws {
        // Input urls and api urls disagree - we're behind with reconciliation, i.e. the package list
        // we process in validation is newer than the package list that has been reconciled when we
        // make the dependencies API call.
        // setup
        Current = .mock
        Current.fetchDependencies = { _ in [
            .init(.p1, dependencies: []),
            .init(.p2, dependencies: [.p3]),
        ]}
        var saved: [PackageURL]? = nil
        Current.fileManager.createFile = { _, data, _ in
            guard let data = data else {
                XCTFail("data must not be nil")
                return false
            }
            guard let list = try? JSONDecoder().decode([PackageURL].self, from: data) else {
                XCTFail("decoding of output failed")
                return false
            }
            saved = list
            return true
        }
        Current.fetchRepositoryAsync = { _, url in
            if url == PackageURL.p3 {
                return .init(defaultBranch: "main", owner: "org", name: "3")
            } else {
                throw Error.unexpectedCall
            }
        }
        Current.fetch = { client, url in
            // getManifestURL -> Github.listRepositoryFilePaths -> Github.fetch
            guard url.absoluteString == "https://api.github.com/repos/org/3/git/trees/main" else {
                return client.eventLoopGroup.next().makeFailedFuture(Error.unexpectedCall)
            }
            return client.eventLoopGroup.next().makeSucceededFuture(
                ByteBuffer(data: .listRepositoryFilePaths(for: "org/3"))
            )
        }
        Current.decodeManifest = { url in
            guard url.absoluteString == "https://raw.githubusercontent.com/org/3/main/Package.swift" else {
                throw Error.unexpectedCall
            }
            return .init(name: "3", products: [], dependencies: [])
        }
        check.packageUrls = [.p1, .p2, .p4]
        check.output = "package.json"

        // MUT
        try await check.run()

        // validate
        XCTAssertEqual(saved, [.p1, .p2, .p3, .p4])
    }

    func test_run_manifest_validation() async throws {
        // Ensure validation via package dump is performed on new packages.
        // setup
        Current = .mock
        Current.fetchDependencies = { _ in [
            .init(.p1, dependencies: []),
            .init(.p2, dependencies: [.p3]),
        ]}
        var saved: [PackageURL]? = nil
        Current.fileManager.createFile = { path, data, _ in
            guard path.hasSuffix("package.json"),
                  let data = data,
                  let list = try? JSONDecoder().decode([PackageURL].self, from: data) else { return false }
            saved = list
            return true
        }
        Current.fetchRepositoryAsync = { _, url in
            if url == PackageURL.p3 {
                return .init(defaultBranch: "main", owner: "org", name: "3")
            } else {
                throw Error.unexpectedCall
            }
        }
        Current.fetch = { client, url in
            // getManifestURL -> Github.listRepositoryFilePaths -> Github.fetch
            guard url.absoluteString == "https://api.github.com/repos/org/3/git/trees/main" else {
                return client.eventLoopGroup.next().makeFailedFuture(Error.unexpectedCall)
            }
            return client.eventLoopGroup.next().makeSucceededFuture(
                ByteBuffer(data: .listRepositoryFilePaths(for: "org/3"))
            )
        }
        Current.decodeManifest = { url in
            guard url.absoluteString == "https://raw.githubusercontent.com/org/3/main/Package.swift" else {
                throw Error.unexpectedCall
            }
            // simulate a bad manifest
            throw AppError.dumpPackageError("simulated decoding error")
        }

        check.packageUrls = [.p1, .p2]
        check.output = "package.json"

        // MUT
        try await check.run()

        // validate
        XCTAssertEqual(saved, [.p1, .p2])
    }

}


private enum Error: Swift.Error { case unexpectedCall }

private extension PackageURL {
    static let p1 = PackageURL(argument: "https://github.com/org/1.git")!
    static let p2 = PackageURL(argument: "https://github.com/org/2.git")!
    static let p3 = PackageURL(argument: "https://github.com/org/3.git")!
    static let p4 = PackageURL(argument: "https://github.com/org/4.git")!
}

private extension CanonicalPackageURL {
    static let p1 = CanonicalPackageURL(prefix: .gitAt, hostname: "github.com", path: "org/1")
    static let p2 = CanonicalPackageURL(prefix: .http, hostname: "github.com", path: "org/2")
    static let p3 = CanonicalPackageURL(prefix: .https, hostname: "github.com", path: "org/3")
}

private extension SwiftPackageIndexAPI.PackageRecord {
    init(_ url: CanonicalPackageURL, dependencies: [CanonicalPackageURL]) {
        self.init(id: .init(), url: url, resolvedDependencies: dependencies)
    }
}

private extension Data {
    static func listRepositoryFilePaths(for path: String) -> Self {
        .init("""
            {
              "url" : "https://api.github.com/repos/\(path)/git/trees/ea8eea9d89842a29af1b8e6c7677f1c86e72fa42",
              "tree" : [
                {
                  "size" : 1122,
                  "type" : "blob",
                  "path" : "Package.swift",
                  "url" : "https://api.github.com/repos/\(path)/git/blobs/bf4aa0c6a8bd9f749c2f96905c40bf2f70ef97d2",
                  "mode" : "100644",
                  "sha" : "bf4aa0c6a8bd9f749c2f96905c40bf2f70ef97d2"
              }
              ],
              "sha" : "ea8eea9d89842a29af1b8e6c7677f1c86e72fa42",
              "truncated" : false
            }
            """.utf8
        )
    }
}
