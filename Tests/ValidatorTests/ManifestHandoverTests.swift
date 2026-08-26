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


final class ManifestHandoverTests: XCTestCase {

    func test_prepare_writes_url_beside_manifests() throws {
        // The evaluation script mounts `manifests` and nothing else, so the url it names a failing
        // package by has to sit outside it.
        Current = .mock
        var created = [String]()
        var written = [String: Data]()
        Current.fileManager.createDirectory = { path, _, _ in created.append(path) }
        Current.fileManager.createFile = { path, data, _ in
            written[path] = data
            return true
        }
        let handover = ManifestHandover(root: "/handover")

        // MUT
        let directory = try handover.prepare(slug: "org_1", url: .p1)

        // validate
        XCTAssertEqual(directory, "/handover/org_1/manifests")
        XCTAssertEqual(created, ["/handover/org_1/manifests"])
        XCTAssertEqual(written["/handover/org_1/url"].map { String(decoding: $0, as: UTF8.self) },
                       PackageURL.p1.absoluteString)
    }

    func test_prepare_rejects_slugs_that_are_not_a_single_path_component() throws {
        Current = .mock
        let handover = ManifestHandover(root: "/handover")

        for slug in ["", ".", "..", "../evil", "org/1", "org_1/../..", ".hidden", "org_1\u{0}x"] {
            XCTAssertThrowsError(try handover.prepare(slug: slug, url: .p1), "expected \(slug) to be rejected")
        }
    }

    func test_validatedURLs_requires_the_evaluation_sign_off() throws {
        // Without the marker "the script never ran" and "the script ran and nothing failed" are the
        // same directory state, and we would add candidates nothing ever evaluated.
        Current = .mock
        Current.fileManager.contentsOfDirectory = { _ in ["org_1"] }
        Current.fileManager.fileExists = { $0 != "/handover/evaluated" }

        XCTAssertThrowsError(try ManifestHandover(root: "/handover").validatedURLs())
    }

    func test_validatedURLs_skips_packages_marked_failed() throws {
        Current = .mock
        Current.fileManager.contentsOfDirectory = { _ in ["org_1", "org_2"] }
        Current.fileManager.fileExists = { $0 != "/handover/org_2/failed" }
        Current.fileManager.contents = { path in
            switch path {
                case "/handover/org_1/url": return Data(PackageURL.p1.absoluteString.utf8)
                case "/handover/org_2/url": return Data(PackageURL.p2.absoluteString.utf8)
                default: return nil
            }
        }

        // MUT
        let urls = try ManifestHandover(root: "/handover").validatedURLs()

        // validate
        XCTAssertEqual(urls, [.p2])
    }

    func test_validatedURLs_ignores_entries_without_manifests() throws {
        // The markers live in the handover root alongside the package directories.
        Current = .mock
        Current.fileManager.contentsOfDirectory = { _ in ["evaluated", "org_1"] }
        Current.fileManager.fileExists = { !$0.hasSuffix("/failed") && $0 != "/handover/evaluated/manifests" }
        Current.fileManager.contents = { _ in Data(PackageURL.p1.absoluteString.utf8) }

        // MUT
        let urls = try ManifestHandover(root: "/handover").validatedURLs()

        // validate
        XCTAssertEqual(urls, [.p1])
    }

    func test_discard_removes_the_package_directory() throws {
        Current = .mock
        var removed = [String]()
        Current.fileManager.removeItem = { removed.append($0) }

        // MUT
        try ManifestHandover(root: "/handover").discard(slug: "org_1")

        // validate
        XCTAssertEqual(removed, ["/handover/org_1"])
    }

    func test_roundtrip_on_a_real_directory() throws {
        Current = .mock
        Current.fileManager = .live
        let root = Foundation.FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try Foundation.FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        defer { try? Foundation.FileManager.default.removeItem(atPath: root) }
        let handover = ManifestHandover(root: root)

        let manifests = try handover.prepare(slug: "org_1", url: .p1)
        _ = try handover.prepare(slug: "org_2", url: .p2)
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: manifests))

        // no sign off yet
        XCTAssertThrowsError(try handover.validatedURLs())

        // the evaluation step failing org_2 and signing off
        Foundation.FileManager.default.createFile(atPath: root + "/org_2/failed", contents: Data())
        Foundation.FileManager.default.createFile(atPath: root + "/evaluated", contents: Data())

        // MUT
        XCTAssertEqual(try handover.validatedURLs(), [.p1])

        try handover.discard(slug: "org_1")
        XCTAssertEqual(try handover.validatedURLs(), [])
    }

}


private extension PackageURL {
    static let p1 = PackageURL(argument: "https://github.com/org/1.git")!
    static let p2 = PackageURL(argument: "https://github.com/org/2.git")!
}
