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
    var resolvePackageRedirects: (EventLoop, PackageURL) -> EventLoopFuture<Redirect>
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
        resolvePackageRedirects: { eventLoop, url in
            resolveRedirects(eventLoop: eventLoop, for: url)
        },
        shell: .live
    )

    static let mock: Self = .init(
        decodeManifest: { _ in fatalError("not implemented") },
        fileManager: .mock,
        fetchRepository: { _, _, _ in fatalError("not implemented") },
        githubToken: { nil },
        resolvePackageRedirects: { eventLoop, url in
            eventLoop.makeSucceededFuture(.initial(url))
        },
        shell: .mock
    )
}


#if DEBUG
var Current: Environment = .live
#else
let Current: Environment = .live
#endif
