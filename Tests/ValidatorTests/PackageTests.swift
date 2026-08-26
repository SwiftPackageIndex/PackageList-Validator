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

import AsyncHTTPClient
import NIO
import NIOHTTP1


final class PackageTests: XCTestCase {

    func test_fetch_multiple_manifests() async throws {
        // A package with four versioned manifest files. All four are handed over: we no longer
        // evaluate them here, so we cannot know which SwiftPM will pick.
        // setup
        Current = .mock
        var manifestsFetched = 0
        var written = [String]()
        Current.fileManager.createFile = { path, _, _ in
            written.append(path)
            return true
        }
        Current.fetch = { client, url in
            switch url.absoluteString {
                case "https://raw.githubusercontent.com/org/1/main/Package.swift",
                    "https://raw.githubusercontent.com/org/1/main/Package@swift-6.swift",
                    "https://raw.githubusercontent.com/org/1/main/Package@swift-4.2.swift",
                    "https://raw.githubusercontent.com/org/1/main/Package@swift-4.swift":
                    manifestsFetched += 1
                    return client.eventLoopGroup.next().makeSucceededFuture(
                        try! .fixture(for: "SemanticVersion-Package.swift")
                    )
                case "https://api.github.com/repos/org/1/git/trees/main":
                    // getManifestURLs -> Github.listRepositoryFilePaths -> Github.fetch
                    return client.eventLoopGroup.next().makeSucceededFuture(
                        try! .fixture(for: "github-files-response-multiple-manifests.json")
                    )
                default:
                    return client.eventLoopGroup.next().makeFailedFuture(
                        Error.unexpectedCall("Current.fetch \(url.absoluteString)")
                    )
            }
        }

        let client = MockClient(response: { .mock(status: .ok) })

        // MUT
        try await Package.fetchManifests(client: client,
                                         repository: .init(defaultBranch: "main", owner: "org", name: "1"),
                                         into: "/handover/org_1/manifests")

        // validate
        XCTAssertEqual(manifestsFetched, 4)
        XCTAssertEqual(written.sorted(), [
            "/handover/org_1/manifests/Package.swift",
            "/handover/org_1/manifests/Package@swift-4.2.swift",
            "/handover/org_1/manifests/Package@swift-4.swift",
            "/handover/org_1/manifests/Package@swift-6.swift",
        ])
    }

    func test_getManifestURLs_ignores_paths_below_the_root() async throws {
        // `Packages/Package.swift` is not this package's manifest, and it used to end up fetched
        // under the same name as the real one, silently replacing it.
        Current = .mock
        Current.fetch = { client, url in
            client.eventLoopGroup.next().makeSucceededFuture(
                .init(string: #"{"tree":[{"type":"blob","path":"Package.swift"},"#
                      + #"{"type":"blob","path":"Packages/Package.swift"},"#
                      + #"{"type":"blob","path":"Sources/PackageX.swift"},"#
                      + #"{"type":"blob","path":"Package@swift-5.swift"}]}"#)
            )
        }

        // MUT
        let urls = try await Package.getManifestURLs(client: MockClient(response: { .mock(status: .ok) }),
                                                     repository: .init(defaultBranch: "main", owner: "org", name: "1"))

        // validate
        XCTAssertEqual(urls.map { $0.rawValue.lastPathComponent },
                       ["Package.swift", "Package@swift-5.swift"])
    }

    func test_fetchManifests_rejects_a_manifest_path_that_escapes_the_directory() async throws {
        // The manifest list comes from the repository, so it is attacker controlled. Nothing it
        // names may be written outside the directory we were handed.
        Current = .mock
        var written = [String]()
        Current.fileManager.createFile = { path, _, _ in
            written.append(path)
            return true
        }
        Current.fetch = { client, url in
            guard url.absoluteString.hasSuffix("/git/trees/main") else {
                return client.eventLoopGroup.next().makeSucceededFuture(.init(string: "manifest"))
            }
            return client.eventLoopGroup.next().makeSucceededFuture(
                .init(string: #"{"tree":[{"type":"blob","path":"Package.swift/../../../etc/evil.swift"}]}"#)
            )
        }

        // MUT
        await XCTAssertThrowsErrorAsync(
            try await Package.fetchManifests(client: MockClient(response: { .mock(status: .ok) }),
                                             repository: .init(defaultBranch: "main", owner: "org", name: "1"),
                                             into: "/handover/org_1/manifests")
        )

        // validate
        XCTAssertEqual(written, [])
    }

}


func XCTAssertThrowsErrorAsync(_ expression: @autoclosure () async throws -> some Any,
                               file: StaticString = #filePath,
                               line: UInt = #line) async {
    do {
        _ = try await expression()
        XCTFail("expected an error to be thrown", file: file, line: line)
    } catch {}
}


struct MockClient: Client {
    var response: () -> HTTPClient.Response

    func execute(request: HTTPClient.Request, deadline: NIODeadline?) -> EventLoopFuture<HTTPClient.Response> {
        eventLoopGroup.next().makeSucceededFuture(response())
    }

    let eventLoopGroup: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
}


extension HTTPClient.Response {
    static func mock(status: HTTPResponseStatus) -> Self {
        .init(host: "host", status: status, version: .http1_1, headers: [:], body: nil)
    }
}


private enum Error: Swift.Error {
    case unexpectedCall(String)
}
