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

    func test_decode_multiple_manifests() async throws {
        // This tests package dump for a package with four versioned package manifest files.
        // We use a captured response for a package which lists four manifest files.
        // For three of them that shouldn't be used we send no data when they are fetched.
        // We mock in the SemanticVersion manifest file for the one that should be decoded.
        // setup
        Current = .mock
        Current.fileManager = .live
        var manifestsFetched = 0
        Current.fetch = { client, url in
            switch url.absoluteString {
                case "https://raw.githubusercontent.com/org/1/main/Package@swift-6.swift":
                    // Package.decode -> fetch manifestURL data
                    manifestsFetched += 1
                    return client.eventLoopGroup.next().makeSucceededFuture(
                        try! .fixture(for: "SemanticVersion-Package.swift")
                    )
                case "https://raw.githubusercontent.com/org/1/main/Package.swift",
                    "https://raw.githubusercontent.com/org/1/main/Package@swift-4.2.swift",
                    "https://raw.githubusercontent.com/org/1/main/Package@swift-4.swift":
                    // Package.decode -> fetch manifestURL data - save bad data in the unrelated manifests to raise an error if used
                    manifestsFetched += 1
                    return client.eventLoopGroup.next().makeSucceededFuture(
                        .init()
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
        Current.shell = .live

        let client = MockClient(response: { .mock(status: .ok) })

        // MUT
        let pkg = try await Package.decode(client: client, repository: .init(defaultBranch: "main", owner: "org", name: "1"))

        // validate
        XCTAssertEqual(manifestsFetched, 4)
        XCTAssertEqual(pkg.name, "SemanticVersion")
    }

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
