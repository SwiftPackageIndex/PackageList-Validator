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


final class CheckDependencies2Tests: XCTestCase {
    var check = CheckDependencies2()

    override func setUp() {
        super.setUp()
        check.apiBaseURL = "unused"
        check.limit = .max
        check.spiApiToken = "unused"
        check.output = "unused"
    }

    func test_basic() async throws {
        // Input urls and api urls agree - we're up-to-date with reconciliation, i.e. the package list
        // we process in validation is the same package list that has been reconciled when we make the
        // dependencies API call.
        // setup
        Current = .mock
        Current.fetchDependencies = { _ in [
            .init(.p1, dependencies: []),
            .init(.p2, dependencies: [.p3]),
        ]}
        var saved: [PackageURL]? = nil
        Current.fileManager.createFile = { _, data, _ in
            guard let data = data else {
                XCTFail("data must not be nil")
                return false
            }
            guard let list = try? JSONDecoder().decode([PackageURL].self, from: data) else {
                XCTFail("decoding of output failed")
                return false
            }
            saved = list
            return true
        }
        check.packageUrls = [.p1, .p2]

        // MUT
        try await check.run()

        // validate
        XCTAssertEqual(saved, [.p1, .p2, .p3])
    }

}


private extension PackageURL {
    static let p1 = PackageURL(argument: "https://github.com/org/1.git")!
    static let p2 = PackageURL(argument: "https://github.com/org/2.git")!
    static let p3 = PackageURL(argument: "https://github.com/org/3.git")!
//    static let p4 = PackageURL(argument: "https://github.com/org/4")!
}

private extension CanonicalPackageURL {
    static let p1 = CanonicalPackageURL(prefix: .gitAt, hostname: "github.com", path: "org/1")
    static let p2 = CanonicalPackageURL(prefix: .http, hostname: "github.com", path: "org/2")
    static let p3 = CanonicalPackageURL(prefix: .https, hostname: "github.com", path: "org/3")
//    static let p4 = CanonicalPackageURL(prefix: .https, hostname: "github.com", path: "org/4")
//    static let p5 = CanonicalPackageURL(prefix: .https, hostname: "github.com", path: "org/5")
}

private extension SwiftPackageIndexAPI.PackageRecord {
    init(_ url: CanonicalPackageURL, dependencies: [CanonicalPackageURL]) {
        self.init(id: .init(), url: url, resolvedDependencies: dependencies)
    }
}
