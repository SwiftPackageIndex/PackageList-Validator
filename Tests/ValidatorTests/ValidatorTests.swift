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

    func test_addintGitExtension() throws {
        let s = "https://github.com/weichsel/ZIPFoundation/"
        XCTAssertEqual(PackageURL(rawValue: URL(string: s)!).addingGitExtension().absoluteString,
                       "https://github.com/weichsel/ZIPFoundation.git")
    }

    func test_decodeResponse() throws {
        let body = """
            {
                "data": {
                    "repository": {
                        "defaultBranchRef": {
                            "name": "swift"
                        },
                        "isFork": true
                    }
                }
            }
            """
        let res = try JSONDecoder().decode(Github.Repository.Response.self,
                                           from: .init(body.utf8))
        XCTAssertEqual(
            res.data,
            .init(repository: .init(defaultBranchRef: .init(name: "swift"),
                                    isFork: true))
        )
    }

    func test_decodeError() throws {
        let body = """
            {
                "data": {
                    "repository": null
                },
                "errors": [
                    {
                        "type": "NOT_FOUND",
                        "path": [
                            "repository"
                        ],
                        "locations": [
                            {
                                "line": 2,
                                "column": 3
                            }
                        ],
                        "message": "Could not resolve to a Repository with the name 'stephencelis/SQLite'."
                    }
                ]
            }
            """
        struct Response: Decodable, Equatable {
            struct Result: Decodable, Equatable {
                var repository: Github.Repository?
            }
            var data: Result
            var errors: [Github.GraphQL.Error]?
        }
        let res = try JSONDecoder().decode(Response.self, from: .init(body.utf8))
        XCTAssertEqual(res.data, .init(repository: nil))
        XCTAssertEqual(res.errors, [
            .init(type: .notFound,
                  path: ["repository"],
                  locations: [.init(line: 2, column: 3)],
                  message: "Could not resolve to a Repository with the name 'stephencelis/SQLite'.")
        ])
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
