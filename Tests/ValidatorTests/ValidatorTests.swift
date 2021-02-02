import XCTest

import Foundation
@testable import ValidatorCore


final class ValidatorTests: XCTestCase {

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
    
}


private extension Array where Element == String {
    var asURLs: [PackageURL] {
        compactMap(URL.init(string:))
            .map(PackageURL.init(rawValue:))
    }
}
