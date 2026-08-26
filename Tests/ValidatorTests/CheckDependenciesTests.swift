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


final class CheckDependenciesTests: XCTestCase {
    var check = CheckDependencies()

    override func setUp() {
        super.setUp()
        check.apiBaseURL = "unused"
        check.input = nil
        check.limit = .max
        check.manifestDir = "/handover"
        check.maxCheck = .max
        check.spiApiToken = "unused"
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
        Current.fetchRepository = { _, url in
            if url == PackageURL.p3 {
                return .init(defaultBranch: "main", owner: "org", name: "3")
            } else {
                throw Error.unexpectedCall
            }
        }
        var handedOver = [String]()
        Current.fetchManifests = { _, repo, directory in
            guard repo.path == "org/3" else { throw Error.unexpectedCall }
            handedOver.append(directory)
        }
        var urlsWritten = [String: String]()
        Current.fileManager.createFile = { path, data, _ in
            urlsWritten[path] = data.map { String(decoding: $0, as: UTF8.self) }
            return true
        }
        check.packageUrls = [.p1, .p2]

        // MUT
        try await check.run()

        // validate
        XCTAssertEqual(handedOver, ["/handover/org_3/manifests"])
        XCTAssertEqual(urlsWritten["/handover/org_3/url"], PackageURL.p3.absoluteString)
    }

    func test_run_does_not_write_a_package_list() async throws {
        // Which candidates get added is decided by add-validated-dependencies, after evaluation.
        // This command deciding it too would add packages nothing ever evaluated.
        Current = .mock
        Current.fetchDependencies = { _ in [
            .init(.p1, dependencies: []),
            .init(.p2, dependencies: [.p3]),
        ]}
        Current.fetchRepository = { _, _ in .init(defaultBranch: "main", owner: "org", name: "3") }
        Current.fetchManifests = { _, _, _ in }
        var saved = [String]()
        Current.fileManager.createFile = { path, _, _ in
            if !path.hasSuffix("/url") { saved.append(path) }
            return true
        }
        check.packageUrls = [.p1, .p2]

        // MUT
        try await check.run()

        // validate
        XCTAssertEqual(saved, [])
    }

    func test_run_discards_a_candidate_whose_manifests_could_not_be_fetched() async throws {
        // A partly fetched package must not be left behind for evaluation - it would be added on
        // the strength of whichever manifests happened to arrive.
        // setup
        Current = .mock
        Current.fetchDependencies = { _ in [
            .init(.p1, dependencies: []),
            .init(.p2, dependencies: [.p3]),
        ]}
        Current.fetchRepository = { _, url in
            if url == PackageURL.p3 {
                return .init(defaultBranch: "main", owner: "org", name: "3")
            } else {
                throw Error.unexpectedCall
            }
        }
        Current.fetchManifests = { _, _, _ in
            throw AppError.ioError("simulated fetch error")
        }
        var removed = [String]()
        Current.fileManager.removeItem = { removed.append($0) }
        check.packageUrls = [.p1, .p2]

        // MUT
        try await check.run()

        // validate
        XCTAssertEqual(removed, ["/handover/org_3"])
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
        Current.fetchRepository = { _, url in throw Error.unexpectedCall }
        Current.fetchManifests = { _, _, _ in throw Error.unexpectedCall }
        Current.fetch = { client, url in
            client.eventLoopGroup.next().makeFailedFuture(Error.unexpectedCall)
        }
        var handedOver = [String]()
        Current.fileManager.createDirectory = { path, _, _ in handedOver.append(path) }
        check.packageUrls = [.p2] // p1 not in input list - it's been removed by CheckRedirect

        // MUT
        try await check.run()

        // validate
        XCTAssertEqual(handedOver, [])
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
