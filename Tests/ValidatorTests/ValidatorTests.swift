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

    func test_unique() throws {
        XCTAssertEqual(["a"].asURLs.uniqued().map(\.absoluteString),
                       ["a"])
        XCTAssertEqual(["A", "a"].asURLs.uniqued().map(\.absoluteString),
                       ["A"])
        XCTAssertEqual(["a", "A"].asURLs.uniqued().map(\.absoluteString),
                       ["a"])
        XCTAssertEqual(["A", "a", "A"].asURLs.uniqued().map(\.absoluteString),
                       ["A"])
        XCTAssertEqual(["a", "A", "a"].asURLs.uniqued().map(\.absoluteString),
                       ["a"])
    }

    func test_Github_packageList() throws {
        XCTAssertFalse(try Github.packageList().isEmpty)
    }

    func test_appendingGitExtension() throws {
        let s = "https://github.com/weichsel/ZIPFoundation/"
        XCTAssertEqual(PackageURL(rawValue: URL(string: s)!).appendingGitExtension().absoluteString,
                       "https://github.com/weichsel/ZIPFoundation.git")
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

    func test_findDependencies() throws {
        // Basic findDependencies test
        // setup
        Current.decodeManifest = { url in .init(
            name: "bar",
            products: [
                .init(name: "prod")
            ],
            dependencies: [
                .init(name: "a",
                      url: PackageURL(argument: "https://github.com/dep/A")!)
            ]) }
        Current.fetchRepository = { client, _, _ in
            client.eventLoopGroup.next().makeSucceededFuture(Github.Repository(default_branch: "main", fork: false))
        }

        // MUT
        let url = PackageURL(argument: "https://github.com/foo/bar")!
        let urls = try findDependencies(packageURL: url, waitIfRateLimited: false, retries: 0)

        // validate
        XCTAssertEqual(urls,
                       [PackageURL(argument: "https://github.com/dep/A.git")!])
    }

}


private extension Array where Element == String {
    var asURLs: [PackageURL] {
        compactMap(URL.init(string:))
            .map(PackageURL.init(rawValue:))
    }
}
