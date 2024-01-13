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


final class EndToEndTests: XCTestCase {
    var redirCheck = Validator.CheckRedirects()
//    var check = CheckDependencies()

    override func setUpWithError() throws {
        try super.setUpWithError()
        redirCheck.chunk = nil
        redirCheck.input = nil
        redirCheck.limit = 10
        redirCheck.numberOfChunks = nil
        redirCheck.offset = 0
        redirCheck.output = nil
        redirCheck.packageUrls = []
        redirCheck.usePackageList = true
        redirCheck.verbose = true

        //        check.apiBaseURL = "unused"
        //        check.input = nil
        //        check.limit = .max
        //        check.maxCheck = .max
        //        check.spiApiToken = "unused"
        //        check.output = "unused"
    }

    func test_issue_2828_not_found() async throws {
        // Redirects found but not reflected in PR
        // - part 1: package is a 404 -> delete package
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2828
        // setup

        // MUT
        // validator check-redirects -i packages.json -o redirect-checked.json
    }

    func test_issue_2828_redirect_exists() async throws {
        // Redirects found but not reflected in PR
        // - part 2: package is a redirect and redirect already indexed -> delete package
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2828

        // MUT
        // validator check-redirects -i packages.json -o redirect-checked.json
        XCTFail("implement")
    }

}


private extension PackageURL {
    static let p1 = PackageURL(argument: "https://github.com/org/1.git")!
    static let p2 = PackageURL(argument: "https://github.com/org/2.git")!
    static let p3 = PackageURL(argument: "https://github.com/org/3.git")!
    static let p4 = PackageURL(argument: "https://github.com/org/4.git")!
}
