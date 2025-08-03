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

@preconcurrency import CanonicalPackageURL
import NIO


final class CheckDependenciesTests: XCTestCase {
    var check = CheckDependencies()

    override func setUp() {
        super.setUp()
        check.apiBaseURL = "unused"
        check.input = nil
        check.limit = .max
        check.maxCheck = .max
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
        Current.fetchRepository = { _, url in
            if url == PackageURL.p3 {
                return .init(defaultBranch: "main", owner: "org", name: "3")
            } else {
                throw Error.unexpectedCall
            }
        }
        var decodeCalled = false
        Current.decodeManifest = { _, repo in
            guard repo.path == "org/3" else { throw Error.unexpectedCall }
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
        Current.fetchRepository = { _, url in
            if url == PackageURL.p3 {
                return .init(defaultBranch: "main", owner: "org", name: "3")
            } else {
                throw Error.unexpectedCall
            }
        }
        Current.decodeManifest = { _, repo in
            guard repo.path == "org/3" else { throw Error.unexpectedCall }
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
        Current.fetchRepository = { _, url in
            if url == PackageURL.p3 {
                return .init(defaultBranch: "main", owner: "org", name: "3")
            } else {
                throw Error.unexpectedCall
            }
        }
        Current.decodeManifest = { _, repo in
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

    func test_issue_2828() async throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2828
        // The input list coming out of RedirectCheck has removed packages. Ensure they are
        // not being put back via the API dependency call's package list.
        Current = .mock
        Current.fetchDependencies = { _ in [
            // p1 is still on the server and is being returned by the dependencies API call
            .init(.p1, dependencies: []),
            .init(.p2, dependencies: []),
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
        Current.fetchRepository = { _, url in throw Error.unexpectedCall }
        Current.fetch = { client, url in
            client.eventLoopGroup.next().makeFailedFuture(Error.unexpectedCall)
        }
        check.packageUrls = [.p2] // p1 not in input list - it's been removed by CheckRedirect
        check.output = "package.json"

        // MUT
        try await check.run()

        // validate
        XCTAssertEqual(saved, [.p2])
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
