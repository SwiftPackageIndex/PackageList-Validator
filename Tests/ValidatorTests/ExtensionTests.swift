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

    func test_allDependencies() throws {
        let records: [SwiftPackageIndexAPI.PackageRecord] = [
            .init(.p1, [.p3]),
            .init(.p2, [.p4]),
            .init(.p3, [.p2, .p4, .p5]),
        ]
        XCTAssertEqual(records.allDependencies.sorted(by: { $0.canonicalPath < $1.canonicalPath }).map(\.path),
                       [CanonicalPackageURL.p2, .p3, .p4, .p5].map(\.path))
    }

    func test_missingDependencies() throws {
        let p1_prime = CanonicalPackageURL(prefix: .https, hostname: "github.com", path: "org/1")
        let records: [SwiftPackageIndexAPI.PackageRecord] = [
            .init(.p1, []),
            .init(.p2, [p1_prime, .p3]),
        ]
        let missing = records.allDependencies.subtracting(.init([.p1, .p2]))
        XCTAssertEqual(missing.count, 1)
        XCTAssertEqual(missing.first?.canonicalPath, CanonicalPackageURL.p3.canonicalPath)
    }

    func test_String_appendingGitExtension() throws {
        XCTAssertEqual("".appendingGitExtension(), ".git")
        XCTAssertEqual("foo".appendingGitExtension(), "foo.git")
        XCTAssertEqual("foo.".appendingGitExtension(), "foo..git")
        XCTAssertEqual("foo/".appendingGitExtension(), "foo.git")
        XCTAssertEqual("foo/.git".appendingGitExtension(), "foo.git")
        XCTAssertEqual("foo.git".appendingGitExtension(), "foo.git")
        XCTAssertEqual("foo.Git".appendingGitExtension(), "foo.git")
        XCTAssertEqual("foo.GIT".appendingGitExtension(), "foo.git")
        XCTAssertEqual("foo.bar".appendingGitExtension(), "foo.bar.git")
    }

    func test_String_deletingGitExtension() throws {
        XCTAssertEqual("foo.git".deletingGitExtension(), "foo")
        XCTAssertEqual("foo..git".deletingGitExtension(), "foo.")
        XCTAssertEqual("foo/.git".deletingGitExtension(), "foo")
        XCTAssertEqual("foo/".deletingGitExtension(), "foo/")
        XCTAssertEqual("foo".deletingGitExtension(), "foo")
        XCTAssertEqual("foo.Git".deletingGitExtension(), "foo")
        XCTAssertEqual("foo.GIT".deletingGitExtension(), "foo")
        XCTAssertEqual("foo.bar.git".deletingGitExtension(), "foo.bar")
    }

    func test_URL_appendingGitExtension() throws {
        XCTAssertEqual(URL(string: "foo")!.appendingGitExtension().absoluteString, "foo.git")
        XCTAssertEqual(URL(string: "foo.")!.appendingGitExtension().absoluteString, "foo..git")
        XCTAssertEqual(URL(string: "foo/")!.appendingGitExtension().absoluteString, "foo.git")
        XCTAssertEqual(URL(string: "foo/.git")!.appendingGitExtension().absoluteString, "foo.git")
        XCTAssertEqual(URL(string: "foo.git")!.appendingGitExtension().absoluteString, "foo.git")
        XCTAssertEqual(URL(string: "foo.Git")!.appendingGitExtension().absoluteString, "foo.git")
        XCTAssertEqual(URL(string: "foo.GIT")!.appendingGitExtension().absoluteString, "foo.git")
        XCTAssertEqual(URL(string: "foo.bar")!.appendingGitExtension().absoluteString, "foo.bar.git")
    }

    func test_URL_deletingGitExtension() throws {
        XCTAssertEqual(URL(string: "foo.git")!.deletingGitExtension().absoluteString, "foo")
        XCTAssertEqual(URL(string: "foo..git")!.deletingGitExtension().absoluteString, "foo.")
        XCTAssertEqual(URL(string: "foo/.git")!.deletingGitExtension().absoluteString, "foo")
        XCTAssertEqual(URL(string: "foo/")!.deletingGitExtension().absoluteString, "foo/")
        XCTAssertEqual(URL(string: "foo")!.deletingGitExtension().absoluteString, "foo")
        XCTAssertEqual(URL(string: "foo.Git")!.deletingGitExtension().absoluteString, "foo")
        XCTAssertEqual(URL(string: "foo.GIT")!.deletingGitExtension().absoluteString, "foo")
        XCTAssertEqual(URL(string: "foo.bar.git")!.deletingGitExtension().absoluteString, "foo.bar")
    }

}


private extension CanonicalPackageURL {
    static let p1 = CanonicalPackageURL(prefix: .gitAt, hostname: "github.com", path: "org/1")
    static let p2 = CanonicalPackageURL(prefix: .http, hostname: "github.com", path: "org/2")
    static let p3 = CanonicalPackageURL(prefix: .https, hostname: "github.com", path: "org/3")
    static let p4 = CanonicalPackageURL(prefix: .https, hostname: "github.com", path: "org/4")
    static let p5 = CanonicalPackageURL(prefix: .https, hostname: "github.com", path: "org/5")
}


private extension SwiftPackageIndexAPI.PackageRecord {
    init(_ url: CanonicalPackageURL, _ dependencies: [CanonicalPackageURL]) {
        self.init(id: .init(), url: url, resolvedDependencies: dependencies)
    }
}
