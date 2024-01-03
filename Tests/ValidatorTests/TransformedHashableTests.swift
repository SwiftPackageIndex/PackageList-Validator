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


final class TransformedHashableTests: XCTestCase {

    func test_Equatable() throws {
        let s1 = TransformedHashable("foo", transform: \.localizedLowercase)
        let s1_a = TransformedHashable("Foo", transform: \.localizedLowercase)
        let s2 = TransformedHashable("foo2", transform: \.localizedLowercase)
        XCTAssertEqual(s1, s1_a)
        XCTAssertFalse(s1 == s2)
    }
     
    func test_Hashable() throws {
        let s1 = TransformedHashable("foo", transform: \.localizedLowercase)
        let s1_a = TransformedHashable("Foo", transform: \.localizedLowercase)
        let s2 = TransformedHashable("foo2", transform: \.localizedLowercase)
        XCTAssertEqual(Set([s1, s1_a, s2]).map(\.value).sorted(), ["foo", "foo2"])
    }

    func test_dymanicMemberLookup() throws {
        let s1 = TransformedHashable("foo", transform: \.localizedLowercase)
        XCTAssertEqual(s1.count, 3)
    }

}
