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


final class UniqueCanonicalPackageURLsTests: XCTestCase {

    func test_insert() throws {
        var set = UniqueCanonicalPackageURLs([.p1])
        XCTAssertEqual(set.insert(CanonicalPackageURL.p1).inserted, false)
        XCTAssertEqual(set.insert(CanonicalPackageURL.p1).memberAfterInsert, .p1)
        XCTAssertEqual(set.map(\.canonicalPath), ["org/1"])
        XCTAssertEqual(set.insert(CanonicalPackageURL.p1_a).inserted, false)
        XCTAssertEqual(set.insert(CanonicalPackageURL.p1_a).memberAfterInsert, .p1)
        XCTAssertEqual(set.map(\.canonicalPath), ["org/1"])
        XCTAssertEqual(set.insert(CanonicalPackageURL.p2).inserted, true)
        XCTAssertEqual(set.insert(CanonicalPackageURL.p2).memberAfterInsert, .p2)
        XCTAssertEqual(set.map(\.canonicalPath).sorted(), ["org/1", "org/2"])
    }

    func test_contains() throws {
        let set = UniqueCanonicalPackageURLs([.p1])
        XCTAssertEqual(set.contains(CanonicalPackageURL.p1), true)
        XCTAssertEqual(set.contains(CanonicalPackageURL.p1_a), true)
        XCTAssertEqual(set.contains(CanonicalPackageURL.p2), false)
    }

}


extension HashedCanonicalPackageURL {
    static let p1 = Self.init(.p1)
    static let p2 = Self.init(.p2)
    static let p3 = Self.init(.p3)
    static let p4 = Self.init(.p4)
    static let p5 = Self.init(.p5)
}


private extension CanonicalPackageURL {
    static let p1 = CanonicalPackageURL(prefix: .gitAt, hostname: "github.com", path: "org/1")
    static let p1_a = CanonicalPackageURL(prefix: .http, hostname: "github.com", path: "org/1")
    static let p2 = CanonicalPackageURL(prefix: .http, hostname: "github.com", path: "org/2")
    static let p3 = CanonicalPackageURL(prefix: .https, hostname: "github.com", path: "org/3")
    static let p4 = CanonicalPackageURL(prefix: .https, hostname: "github.com", path: "org/4")
    static let p5 = CanonicalPackageURL(prefix: .https, hostname: "github.com", path: "org/5")
}
