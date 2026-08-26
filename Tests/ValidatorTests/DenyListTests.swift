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


final class DenyListTests: XCTestCase {

    func test_excluding_is_case_insensitive() throws {
        let packages = [
            "https://example.com/owner1/repo1",
            "https://example.com/owner1/repo2",
            "https://example.com/OWNER2/REPO1",
            "https://example.com/owner2/repo2",
            "https://example.com/owner2/repo3",
        ].asURLs
        let denied = [
            "https://example.com/owner1/repo1",
            "https://example.com/owner2/repo1", // deliberately a different case
        ].asURLs

        // MUT
        let kept = DenyList(urls: denied).excluding(packages)

        XCTAssertEqual(kept, [
            "https://example.com/owner1/repo2",
            "https://example.com/owner2/repo2",
            "https://example.com/owner2/repo3",
        ].asURLs)
    }

    func test_excluding_matches_on_the_git_suffix_as_written() throws {
        // denylist.json spells every entry with .git, and so does the candidate side, so the two
        // line up without either normalising the suffix away.
        let packages = ["https://example.com/o/a.git", "https://example.com/o/b.git"].asURLs
        let denied = ["https://example.com/O/A.git"].asURLs

        XCTAssertEqual(DenyList(urls: denied).excluding(packages),
                       ["https://example.com/o/b.git"].asURLs)
    }

    func test_contains_matches_regardless_of_case() throws {
        let list = DenyList(urls: ["https://github.com/Fleuronic/Emissary.git"].asURLs)

        XCTAssertTrue(list.contains(PackageURL(argument: "https://github.com/Fleuronic/Emissary.git")!))
        XCTAssertTrue(list.contains(PackageURL(argument: "https://github.com/fleuronic/emissary.git")!))
        XCTAssertFalse(list.contains(PackageURL(argument: "https://github.com/Fleuronic/Other.git")!))
    }

    func test_empty_keeps_everything() throws {
        let packages = ["https://example.com/a/b.git"].asURLs

        XCTAssertEqual(DenyList.empty.excluding(packages), packages)
    }

    func test_load_reads_the_package_url_key() throws {
        Current = .mock
        Current.fileManager.contents = { _ in
            Data("""
                [{"notes": "why", "package_url": "https://github.com/o/r.git"}]
                """.utf8)
        }

        // MUT
        let list = try DenyList.load(from: "denylist.json")

        XCTAssertTrue(list.contains(PackageURL(argument: "https://github.com/o/r.git")!))
    }

    func test_load_rejects_an_unparsable_url() throws {
        Current = .mock
        Current.fileManager.contents = { _ in
            Data(#"[{"package_url": "http://[bad"}]"#.utf8)
        }

        XCTAssertThrowsError(try DenyList.load(from: "denylist.json"))
    }

}
