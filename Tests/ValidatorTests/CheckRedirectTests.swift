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


final class CheckRedirectTests: XCTestCase {

    func test_process_new_redirect() async throws {
        // setup - redirected to URL is new
        Validator.CheckRedirects.normalizedPackageURLs = .init(inputURLs: [.p1])

        // MUT
        let res = try await Validator.CheckRedirects.process(redirect: .redirected(to: .p2),
                                                             verbose: true,
                                                             index: 0,
                                                             packageURL: .p1)
        XCTAssertEqual(res, .p2)
    }

    func test_process_existing_redirect() async throws {
        // setup - redirected to URL is already known
        Validator.CheckRedirects.normalizedPackageURLs = .init(inputURLs: [.p1, .p2])

        // MUT
        let res = try await Validator.CheckRedirects.process(redirect: .redirected(to: .p2),
                                                             verbose: true,
                                                             index: 0,
                                                             packageURL: .p1)
        XCTAssertEqual(res, nil)
    }

}


private extension PackageURL {
    static let p1 = PackageURL(argument: "https://github.com/org/1.git")!
    static let p2 = PackageURL(argument: "https://github.com/org/2.git")!
}
