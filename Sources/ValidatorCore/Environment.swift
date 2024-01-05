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
    var decodeManifest: (_ url: Package.ManifestURL) throws -> Package
    var fileManager: FileManager
    var fetch: (_ client: HTTPClient, _ url: URL) -> EventLoopFuture<ByteBuffer>
    var fetchDependencies: (_ api: SwiftPackageIndexAPI) async throws -> [SwiftPackageIndexAPI.PackageRecord]
    var fetchRepositoryAsync: (_ client: HTTPClient, _ url: PackageURL) async throws -> Github.Repository
    var githubToken: () -> String?
    var resolvePackageRedirects: (EventLoop, PackageURL) -> EventLoopFuture<Redirect>
    var resolvePackageRedirectsAsync: (PackageURL) async -> Redirect
    var shell: Shell
}


extension Environment {
    static let live: Self = .init(
        decodeManifest: { url in try Package.decode(from: url) },
        fileManager: .live,
        fetch: Github.fetch(client:url:),
        fetchDependencies: { try await $0.fetchDependencies() },
        fetchRepositoryAsync: Github.fetchRepository(client:url:),
        githubToken: { ProcessInfo.processInfo.environment["GITHUB_TOKEN"] },
        resolvePackageRedirects: resolveRedirects(eventLoop:for:),
        resolvePackageRedirectsAsync: resolveRedirects(for:),
        shell: .live
    )

    static let mock: Self = .init(
        decodeManifest: { _ in fatalError("not implemented") },
        fileManager: .mock,
        fetch: { client, _ in client.eventLoopGroup.next().makeFailedFuture(AppError.runtimeError("unimplemented")) },
        fetchDependencies: { _ in [] },
        fetchRepositoryAsync: { _, _ in .init(defaultBranch: "main", owner: "foo", name: "bar") },
        githubToken: { nil },
        resolvePackageRedirects: { eventLoop, url in
            eventLoop.makeSucceededFuture(.initial(url))
        },
        resolvePackageRedirectsAsync: { .initial($0) },
        shell: .mock
    )
}


#if DEBUG
var Current: Environment = .live
#else
let Current: Environment = .live
#endif
