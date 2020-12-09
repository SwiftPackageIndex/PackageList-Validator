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
        let body = "{\"data\":{\"repository\":{\"defaultBranchRef\":{\"name\":\"swift\"},\"isFork\":true}}}"
        struct Response: Decodable, Equatable {
            struct Result: Decodable, Equatable {
                var repository: Github.Repository
            }
            var data: Result
        }
        let res = try JSONDecoder().decode(Response.self, from: .init(body.utf8))
        XCTAssertEqual(
            res,
            .init(data: .init(
                repository: .init(defaultBranchRef: .init(name: "swift"),
                                  isFork: true)
            ))
        )
    }
}


private extension Array where Element == String {
    var asURLs: [PackageURL] {
        compactMap(URL.init(string:))
            .map(PackageURL.init(rawValue:))
    }
}
