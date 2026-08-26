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


final class AddValidatedDependenciesTests: XCTestCase {
    var add = AddValidatedDependencies()
    var savedList: [PackageURL]?

    override func setUp() {
        super.setUp()
        add.input = nil
        add.manifestDir = "/handover"
        add.output = "package.json"
        savedList = nil
    }

    func test_run_adds_evaluated_packages_to_the_list() throws {
        // setup
        Current = .mock
        handover(["org_3": .p3])
        captureSavedList()
        add.packageUrls = [.p1, .p2]

        // MUT
        try add.run()

        // validate
        XCTAssertEqual(savedList, [.p1, .p2, .p3])
    }

    func test_run_keeps_input_urls_the_server_has_not_caught_up_with() throws {
        // Input urls and api urls disagree - the list we process is newer than the one the
        // dependencies API call was reconciled against. Nothing on the input list may be dropped.
        // setup
        Current = .mock
        handover(["org_3": .p3])
        captureSavedList()
        add.packageUrls = [.p1, .p2, .p4]

        // MUT
        try add.run()

        // validate
        XCTAssertEqual(savedList, [.p1, .p2, .p3, .p4])
    }

    func test_run_does_not_add_a_package_already_on_the_list() throws {
        // setup
        Current = .mock
        handover(["org_1": .p1])
        captureSavedList()
        add.packageUrls = [.p1, .p2]

        // MUT
        try add.run()

        // validate
        XCTAssertEqual(savedList, [.p1, .p2])
    }

    func test_run_refuses_a_handover_that_was_never_evaluated() throws {
        // The whole point of the split: a directory with no sign off has had no third party code
        // run over it, and adding from it would defeat the evaluation step entirely.
        Current = .mock
        Current.fileManager.contentsOfDirectory = { _ in ["org_3"] }
        Current.fileManager.fileExists = { $0 != "/handover/evaluated" }
        add.packageUrls = [.p1]

        XCTAssertThrowsError(try add.run())
    }

    // Mocks a handover directory the evaluation step has signed off on, with every listed package
    // having loaded.
    private func handover(_ packages: [String: PackageURL]) {
        Current.fileManager.contentsOfDirectory = { _ in Array(packages.keys) }
        Current.fileManager.fileExists = { !$0.hasSuffix("/\(ManifestHandover.failedMarker)") }
        Current.fileManager.contents = { path in
            packages.first { path == "/handover/\($0.key)/url" }
                .map { Data($0.value.absoluteString.utf8) }
        }
    }

    private func captureSavedList() {
        Current.fileManager.createFile = { [unowned self] path, data, _ in
            guard path.hasSuffix("package.json"), let data else { return false }
            savedList = try? JSONDecoder().decode([PackageURL].self, from: data)
            return true
        }
    }
}


private extension PackageURL {
    static let p1 = PackageURL(argument: "https://github.com/org/1.git")!
    static let p2 = PackageURL(argument: "https://github.com/org/2.git")!
    static let p3 = PackageURL(argument: "https://github.com/org/3.git")!
    static let p4 = PackageURL(argument: "https://github.com/org/4.git")!
}
