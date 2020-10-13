import ArgumentParser
import AsyncHTTPClient
import Foundation
import NIO
import NIOHTTP1
import Darwin.C


extension Validator {
    struct CheckDependencies: ParsableCommand {
        @Option(name: .shortAndLong, help: "limit number of urls to check")
        var limit: Int?

        @Option(name: .shortAndLong, help: "save changes to output file")
        var output: String?

        @Argument(help: "Package urls to check")
        var packageUrls: [URL] = []

        @Flag(name: .shortAndLong, help: "follow redirects")
        var follow = false

        @Flag(name: .long, help: "check redirects of canonical package list")
        var usePackageList = false

        func validate() throws {
            guard
                usePackageList || !packageUrls.isEmpty,
                !(usePackageList && !packageUrls.isEmpty) else {
                throw ValidationError("Specify either a list of packages or --usePackageList")
            }
        }

        mutating func run() throws {
            if Current.githubToken() == nil {
                print("Warning: Using anonymous authentication -- you will quickly run into rate limiting issues\n")
            }

            packageUrls = usePackageList
                ? try fetchPackageList()
                : packageUrls

            if let limit = limit {
                packageUrls = Array(packageUrls.prefix(limit))
            }

            print("Checking dependencies ...")
            let client = HTTPClient(eventLoopGroupProvider: .createNew)
            defer { try? client.syncShutdown() }

            let updated = try packageUrls.flatMap { packageURL -> [URL] in
                try findDependencies(client: client, url: packageURL, followRedirects: follow)
                    .wait()
                    + [packageURL]
            }
            .deletingDuplicates()
            .sorted(by: { $0.absoluteString.lowercased() < $1.absoluteString.lowercased() })

            if let path = output {
                try saveList(updated, path: path)
            }
        }
    }
}


struct Repository: Codable {
    let default_branch: String
    let fork: Bool
}


struct Product: Decodable {
    let name: String
}


struct Dependency: Decodable, Hashable {
    let name: String
    let url: URL
}


struct Package: Decodable {
    let name: String
    let products: [Product]
    let dependencies: [Dependency]
}


func dumpPackage(manifestURL: URL) throws -> Package {
    try withTempDir { tempDir in
        let fileURL = URL(fileURLWithPath: tempDir).appendingPathComponent("Package.swift")
        let data = try Data(contentsOf: manifestURL)
        guard Current.fileManager.createFile(fileURL.path, data, nil) else {
            throw AppError.dumpPackageError("failed to save manifest \(manifestURL.absoluteString) to temp directory \(fileURL.absoluteString)")
        }
        guard let pkgJSON = try Current.shell.run(command: .packageDump, at: tempDir)
                .data(using: .utf8) else {
            throw AppError.dumpPackageError("package dump did not return data")
        }
        return try JSONDecoder().decode(Package.self, from: pkgJSON)
    }
}


func resolvePackageRedirects(eventLoop: EventLoop, urls: [URL], followRedirects: Bool = false) -> EventLoopFuture<[URL]> {
    let req = urls.map { url -> EventLoopFuture<URL> in
        followRedirects
            ? resolvePackageRedirects(eventLoop: eventLoop,
                                      for: url).map(\.url)
            : eventLoop.makeSucceededFuture(url)
    }
    return EventLoopFuture.whenAllSucceed(req, on: eventLoop)
}


func fetchRepository(client: HTTPClient, url: URL) -> EventLoopFuture<Repository> {
    let repository = url.deletingPathExtension().lastPathComponent
    let owner = url.deletingLastPathComponent().lastPathComponent
    return fetchRepository(client: client, owner: owner, repository: repository)
}


var repositoryCache = Cache<Repository>()


func fetchRepository(client: HTTPClient, owner: String, repository: String) -> EventLoopFuture<Repository> {
    let url = URL(string: "https://api.github.com/repos/\(owner)/\(repository)")!
    if let cached = repositoryCache[Cache.Key(string: url.absoluteString)] {
        return client.eventLoopGroup.next().makeSucceededFuture(cached)
    }
    return fetch(Repository.self, client: client, url: url)
        .map { repo in
            repositoryCache[Cache.Key(string: url.absoluteString)] = repo
            return repo
        }
}


func fetchRepositories(client: HTTPClient, urls: [URL]) -> EventLoopFuture<[(URL, Repository)]> {
    let req = urls.map { url in
        fetchRepository(client: client, url: url)
            .map { (url, $0) }
    }
    return EventLoopFuture.whenAllSucceed(req, on: client.eventLoopGroup.next())
}


func dropForks(client: HTTPClient, urls: [URL]) -> EventLoopFuture<[URL]> {
    fetchRepositories(client: client, urls: urls)
        .map { pairs in
            pairs.filter { (url, repo) in !repo.fork }
            .map { (url, repo) in url }
        }
}


func findDependencies(client: HTTPClient, url: URL, followRedirects: Bool = false) throws -> EventLoopFuture<[URL]> {
    let el = client.eventLoopGroup.next()
    return getManifestURL(client: client, url: url)
        .flatMapThrowing {
            try dumpPackage(manifestURL: $0)
        }
        .map { $0.dependencies
            .filter { $0.url.scheme == "https" }
            .map { $0.url.addingGitExtension() }
        }
        .flatMap { resolvePackageRedirects(eventLoop: el,
                                           urls: $0,
                                           followRedirects: followRedirects) }
        .flatMap { dropForks(client: client, urls: $0) }
        .map { urls in
            if !urls.isEmpty {
                print("Dependencies for \(url.absoluteString)")
                urls.forEach {
                    print("  - \($0.absoluteString)")
                }
            }
            return urls
        }
}


func rateLimitStatus(_ response: HTTPClient.Response) -> RateLimitStatus {
    if
        response.status == .forbidden,
        let remaining = response.headers.first(name: "X-RateLimit-Remaining")
            .flatMap(Int.init),
        let reset = response.headers.first(name: "X-RateLimit-Reset")
            .flatMap(TimeInterval.init)
            .flatMap(Date.init(timeIntervalSince1970:))
         {
        if remaining == 0 {
            return .limited(until: reset)
        } else {
            return .unknown
        }
    }
    return .ok
}


enum RateLimitStatus {
    case limited(until: Date)
    case ok
    case unknown
}


func fetch<T: Decodable>(_ type: T.Type, client: HTTPClient, url: URL) -> EventLoopFuture<T> {
    let eventLoop = client.eventLoopGroup.next()
    let headers = HTTPHeaders([
        ("User-Agent", "SPI-Validator"),
        Current.githubToken().map { ("Authorization", "Bearer \($0)") }
    ].compactMap({ $0 }))

    do {
        let request = try HTTPClient.Request(url: url, method: .GET, headers: headers)
        return client.execute(request: request)
            .flatMap { response in
                if case let .limited(until: reset) = rateLimitStatus(response) {
                    let delay = UInt32(max(0, reset.timeIntervalSinceNow) + 1)
                    print("rate limit will reset at \(reset) (in \(delay)s)")
                    print("sleeping until then ...")
                    fflush(stdout)
                    sleep(delay)
                    return fetch(T.self, client: client, url: url)
                    //  return eventLoop.makeFailedFuture(AppError.rateLimited(until: reset))
                }
                guard let body = response.body else {
                    return eventLoop.makeFailedFuture(AppError.noData(url))
                }
                do {
                    let content = try JSONDecoder().decode(type, from: body)
                    return eventLoop.makeSucceededFuture(content)
                } catch {
                    let json = body.getString(at: 0, length: body.readableBytes) ?? "(nil)"
                    return eventLoop.makeFailedFuture(AppError.decodingError(error, json: json))
                }
            }
    } catch {
        return eventLoop.makeFailedFuture(error)
    }
}


func getManifestURL(client: HTTPClient, url: URL) -> EventLoopFuture<URL> {
    let repository = url.deletingPathExtension().lastPathComponent
    let owner = url.deletingLastPathComponent().lastPathComponent
    return fetchRepository(client: client, owner: owner, repository: repository)
        .map(\.default_branch)
        .map { defaultBranch in
            URL(string: "https://raw.githubusercontent.com/\(owner)/\(repository)/\(defaultBranch)/Package.swift")!
        }
}
