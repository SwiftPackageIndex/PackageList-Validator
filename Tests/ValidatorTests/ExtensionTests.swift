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


final class ExtensionsTests: XCTestCase {

    func test_missingDependencies() throws {
        let p1 = CanonicalPackageURL(prefix: .gitAt, hostname: "github.com", path: "org/1")
        let p1_prime = CanonicalPackageURL(prefix: .https, hostname: "github.com", path: "org/1")
        let p2 = CanonicalPackageURL(prefix: .http, hostname: "github.com", path: "org/2")
        let p3 = CanonicalPackageURL(prefix: .https, hostname: "github.com", path: "org/3")
        let records: [SwiftPackageIndexAPI.PackageRecord] = [
            .init(id: .init(), url: p1, resolvedDependencies: []),
            .init(id: .init(), url: p2, resolvedDependencies: [p1_prime, p3]),
        ]
        let missing = records.missingDependencies()
        XCTAssertEqual(missing.count, 1)
        XCTAssertEqual(missing.first?.canonicalPath, p3.canonicalPath)
    }

}
