// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import AsyncHTTPClient
import Foundation
import NIO


struct Environment {
    var decodeManifest: (_ url: Package.ManifestURL) throws -> Package
    var fileManager: FileManager
    var fetchRepository: (_ client: HTTPClient,
                          _ owner: String,
                          _ repository: String) -> EventLoopFuture<Github.Repository>
    var githubToken: () -> String?
    var resolvePackageRedirects: (RedirectFollower.Client, PackageURL) -> EventLoopFuture<Redirect>
    var shell: Shell
}


extension Environment {
    static let live: Self = .init(
        decodeManifest: { url in try Package.decode(from: url) },
        fileManager: .live,
        fetchRepository: { client, owner, repository in
            Github.fetchRepository(client: client,
                                   owner: owner,
                                   repository: repository) },
        githubToken: { ProcessInfo.processInfo.environment["GITHUB_TOKEN"] },
        resolvePackageRedirects: { client, url in
            RedirectFollower.resolvePackageRedirects(client: client, url: url)
        },
        shell: .live
    )

    static let mock: Self = .init(
        decodeManifest: { _ in fatalError("not implemented") },
        fileManager: .mock,
        fetchRepository: { client, _, _ in
            client.eventLoopGroup.next().makeSucceededFuture(
                Github.Repository(default_branch: "main", fork: false)) },
        githubToken: { nil },
        resolvePackageRedirects: { client, url in
            client.eventLoop.makeSucceededFuture(.initial(url.absoluteString))
        },
        shell: .mock
    )
}


#if DEBUG
var Current: Environment = .live
#else
let Current: Environment = .live
#endif
