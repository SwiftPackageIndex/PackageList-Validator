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
}


private extension Array where Element == String {
    var asURLs: [URL] {
        compactMap(URL.init(string:))
    }
}
