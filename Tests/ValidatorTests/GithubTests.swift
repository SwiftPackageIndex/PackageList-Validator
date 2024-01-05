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


final class GithubTests: XCTestCase {

    func test_fetchRepository_retry() async throws {
        // setup
        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        defer { try? client.syncShutdown() }
        let repo = Github.Repository(defaultBranch: "main", owner: "foo", name: "bar")
        var calls = 0
        Current.fetch = { client, _ in
            calls += 1
            if calls < 3 {
                return client.eventLoopGroup.next().makeFailedFuture(AppError.rateLimited(until: .now))
            } else {
                return client.eventLoopGroup.next().makeSucceededFuture(.init(data: repo.data))
            }
        }

        // MUT
        let res = try await Github.fetchRepository(client: client, url: .p1)

        // validate
        XCTAssertEqual(calls, 3)
        XCTAssertEqual(res, repo)
    }

    func test_fetchRepository_retryLimitExceeded() async throws {
        // setup
        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        defer { try? client.syncShutdown() }
        var calls = 0
        Current.fetch = { client, _ in
            calls += 1
            return client.eventLoopGroup.next().makeFailedFuture(AppError.rateLimited(until: .now))
        }

        // MUT
        do {
            _ = try await Github.fetchRepository(client: client, url: .p1)
            XCTFail("expected error to be thrown")
        } catch AppError.retryLimitExceeded {
            // expected error
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        // validate
        XCTAssertEqual(calls, 3)
    }

    func test_listRepositoryFilePaths() async throws {
        // setup
        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        defer { try? client.syncShutdown() }
        let data = try fixtureData(for: "github-files-response.json")
        Current.fetch = { client, _ in
            return client.eventLoopGroup.next().makeSucceededFuture(ByteBuffer(data: data))
        }
        let repo = Github.Repository(defaultBranch: "main", owner: "SwiftPackageIndex", name: "SemanticVersion")

        // MUT
        let paths = try await Github.listRepositoryFilePaths(client: client, repository: repo)

        // validate
        XCTAssertEqual(paths, [".gitignore", ".spi.yml", "FUNDING.yml", "LICENSE", "Package.swift", "README.md"])
    }

}


private extension PackageURL {
    static let p1 = Self.init(URL(string: "https://github.com/foo/bar")!)
}

private extension Github.Repository {
    var data: Data {
        try! JSONEncoder().encode(self)
    }
}
