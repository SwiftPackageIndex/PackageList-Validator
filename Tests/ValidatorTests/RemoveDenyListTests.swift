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

import Foundation
@testable import ValidatorCore

final class RemoveDenyListTests: XCTestCase {

    func test_processPackageDenyList() throws {
        let packageList = [
            "https://example.com/owner1/repo1",
            "https://example.com/owner1/repo2",
            "https://example.com/OWNER2/REPO1",
            "https://example.com/owner2/repo2",
            "https://example.com/owner2/repo3"
        ].map { PackageURL(rawValue: URL(string: $0)!) }

        let denyList = [
            "https://example.com/owner1/repo1",
            "https://example.com/owner2/repo1" // Deliberately a different case
        ].map { PackageURL(rawValue: URL(string: $0)!) }

        // MUT
        let command = Validator.ApplyDenyList()
        let processedList = command.processPackageDenyList(packageList: packageList, denyList: denyList)

        XCTAssertEqual(processedList, [
            "https://example.com/owner1/repo2",
            "https://example.com/owner2/repo2",
            "https://example.com/owner2/repo3"
        ].map { PackageURL(rawValue: URL(string: $0)!) })
    }

}
