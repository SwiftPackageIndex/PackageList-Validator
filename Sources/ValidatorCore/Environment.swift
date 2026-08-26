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

import Foundation

import AsyncHTTPClient
import NIO


struct Environment {
    var fetchManifests: (_ client: Client, _ repository: Github.Repository, _ directory: String) async throws -> Void
    var fileManager: FileManager
    var fetch: (_ client: Client, _ url: URL) -> EventLoopFuture<ByteBuffer>
    var fetchDependencies: (_ api: SwiftPackageIndexAPI) async throws -> [SwiftPackageIndexAPI.PackageRecord]
    var fetchRepository: (_ client: Client, _ url: PackageURL) async throws -> Github.Repository
    var githubToken: () -> String?
    var resolvePackageRedirects: (_ client: Client, _ url: PackageURL) async throws -> Redirect
}


extension Environment {
    static let live: Self = .init(
        fetchManifests: { client, repo, directory in
            try await Package.fetchManifests(client: client, repository: repo, into: directory)
        },
        fileManager: .live,
        fetch: Github.fetch(client:url:),
        fetchDependencies: { try await $0.fetchDependencies() },
        fetchRepository: Github.fetchRepository(client:url:),
        githubToken: { ProcessInfo.processInfo.environment["GITHUB_TOKEN"] },
        resolvePackageRedirects: resolvePackageRedirects(client:for:)
    )

    static let mock: Self = .init(
        fetchManifests: { _, _, _ in fatalError("not implemented") },
        fileManager: .mock,
        fetch: { client, _ in client.eventLoopGroup.next().makeFailedFuture(AppError.runtimeError("unimplemented")) },
        fetchDependencies: { _ in [] },
        fetchRepository: { _, _ in .init(defaultBranch: "main", owner: "foo", name: "bar") },
        githubToken: { nil },
        resolvePackageRedirects: { _, url in .initial(url) }
    )
}


protocol Client {
    var eventLoopGroup: EventLoopGroup { get }
    func execute(request: HTTPClient.Request, deadline: NIODeadline?) -> EventLoopFuture<HTTPClient.Response>
}
extension Client {
    func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
        execute(request: request, deadline: nil)
    }
}

extension HTTPClient: Client { }


#if DEBUG
var Current: Environment = .live
#else
let Current: Environment = .live
#endif
