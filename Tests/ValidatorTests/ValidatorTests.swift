import XCTest

import Foundation
@testable import ValidatorCore


final class ValidatorTests: XCTestCase {

    func test_mergingAdditions() throws {
        XCTAssertEqual(["a"].asURLs.mergingAdditions(with: ["a"].asURLs)
                        .map(\.absoluteString), ["a"])
        XCTAssertEqual(["a"].asURLs.mergingAdditions(with: ["A"].asURLs)
                        .map(\.absoluteString), ["A"])
        XCTAssertEqual(["A"].asURLs.mergingAdditions(with: ["a"].asURLs)
                        .map(\.absoluteString), ["a"])
        XCTAssertEqual(["a", "A"].asURLs.mergingAdditions(with: ["A"].asURLs)
                        .map(\.absoluteString), ["A"])
        XCTAssertEqual(["A", "a", "A"].asURLs.mergingAdditions(with: ["A"].asURLs)
                        .map(\.absoluteString), ["A"])
        XCTAssertEqual(["A", "a", "A"].asURLs.mergingAdditions(with: ["a"].asURLs)
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
    
}


private extension Array where Element == String {
    var asURLs: [PackageURL] {
        compactMap(URL.init(string:))
            .map(PackageURL.init(rawValue:))
    }
}
