import XCTest

import Foundation
@testable import ValidatorCore


final class ValidatorTests: XCTestCase {
    func test_deletingDuplicates() throws {
        XCTAssertEqual(["a"].asURLs.deletingDuplicates().map(\.absoluteString), ["a"])
        XCTAssertEqual(["a", "A"].asURLs.deletingDuplicates().map(\.absoluteString), ["a"])
        XCTAssertEqual(["A", "a"].asURLs.deletingDuplicates().map(\.absoluteString), ["A"])
        XCTAssertEqual(["A", "a", "A"].asURLs.deletingDuplicates().map(\.absoluteString), ["A"])
    }

    func test_Github_packageList() throws {
        XCTAssertFalse(try Github.packageList().isEmpty)
    }
}


private extension Array where Element == String {
    var asURLs: [PackageURL] {
        compactMap(URL.init(string:))
            .map(PackageURL.init(rawValue:))
    }
}
