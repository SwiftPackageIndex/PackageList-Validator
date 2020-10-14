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

        @Option(name: .shortAndLong, help: "read input from file")
        var input: String?

        @Option(name: .shortAndLong, help: "save changes to output file")
        var output: String?

        @Argument(help: "Package urls to check")
        var packageUrls: [PackageURL] = []

        @Flag(name: .shortAndLong, help: "follow redirects")
        var follow = false

        @Flag(name: .long, help: "check redirects of canonical package list")
        var usePackageList = false

        var inputSource: InputSource {
            switch (input, usePackageList, packageUrls.count) {
                case (.some(let fname), false, 0):
                    return .file(fname)
                case (.none, true, 0):
                    return .packageList
                case (.none, false, 1...):
                    return .packageURLs(packageUrls)
                default:
                    return .invalid
            }
        }

        func validate() throws {
            if case .invalid = inputSource {
                throw ValidationError("Specify either an input file (--input), --usePackageList, or a list of package URLs")
            }
        }

        mutating func run() throws {
            if Current.githubToken() == nil {
                print("Warning: Using anonymous authentication -- you will quickly run into rate limiting issues\n")
            }

            let inputURLs = try inputSource.packageURLs()
            let prefix = limit ?? inputURLs.count

            print("Checking dependencies (\(prefix) packages) ...")

            let updated = try inputURLs
                .prefix(prefix)
                .flatMap { packageURL in
                    try [packageURL] +
                        findDependencies(packageURL: packageURL,
                                         followRedirects: follow,
                                         waitIfRateLimited: true)
                }
                .deletingDuplicates()
                .sorted(by: { $0.lowercased() < $1.lowercased() })

            if let path = output {
                try Current.fileManager.saveList(updated, path: path)
            }
        }
    }
}


func resolvePackageRedirects(eventLoop: EventLoop, urls: [PackageURL], followRedirects: Bool = false) -> EventLoopFuture<[PackageURL]> {
    let req = urls.map { url -> EventLoopFuture<PackageURL> in
        followRedirects
            ? resolvePackageRedirects(eventLoop: eventLoop,
                                      for: url).map(\.url)
            : eventLoop.makeSucceededFuture(url)
    }
    return EventLoopFuture.whenAllSucceed(req, on: eventLoop)
}


func dropForks(client: HTTPClient, urls: [PackageURL]) -> EventLoopFuture<[PackageURL]> {
    Github.fetchRepositories(client: client, urls: urls)
        .map { pairs in
            pairs.filter { (url, repo) in !repo.fork }
            .map { (url, repo) in url }
        }
}


func dropNoProducts(client: HTTPClient, packageURLs: [PackageURL]) -> EventLoopFuture<[PackageURL]> {
    let req = packageURLs
        .map { packageURL in
            Package.getManifestURL(client: client, packageURL: packageURL)
                .map { (packageURL, $0) }
        }
    return EventLoopFuture.whenAllSucceed(req, on: client.eventLoopGroup.next())
        .map { pairs in
            pairs.filter { (_, manifestURL) in
                guard let pkg = try? Package.decode(from: manifestURL) else { return false }
                return !pkg.products.isEmpty
            }
            .map { (packageURL, _) in packageURL }
        }
}


func findDependencies(packageURL: PackageURL, followRedirects: Bool, waitIfRateLimited: Bool) throws -> [PackageURL] {
    do {
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { try? client.syncShutdown() }
        return try findDependencies(client: client,
                                    url: packageURL,
                                    followRedirects: followRedirects).wait()
    } catch AppError.rateLimited(until: let reset) where waitIfRateLimited {
        print("rate limit will reset at \(reset)")
        let delay = UInt32(max(0, reset.timeIntervalSinceNow) + 60)
        print("sleeping for \(delay) seconds ...")
        fflush(stdout)
        sleep(delay)
        print("now: \(Date())")

        // Create a new client so we don't run into HTTPClientError.remoteConnectionClosed
        // when the delay exceeds 60s. (We could try and create a custom config with
        // higher maximumAllowedIdleTimeInConnectionPool but it's quite fiddly.
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { try? client.syncShutdown() }
        return try findDependencies(client: client,
                                    url: packageURL,
                                    followRedirects: followRedirects).wait()
    }
}


func findDependencies(client: HTTPClient, url: PackageURL, followRedirects: Bool = false) throws -> EventLoopFuture<[PackageURL]> {
    let el = client.eventLoopGroup.next()
    return Package.getManifestURL(client: client, packageURL: url)
        .flatMapThrowing {
            try Package.decode(from: $0)
        }
        .map { $0.dependencies
            .filter { $0.url.scheme == "https" }
            .map { $0.url.addingGitExtension() }
        }
        .flatMap { resolvePackageRedirects(eventLoop: el,
                                           urls: $0,
                                           followRedirects: followRedirects) }
        .flatMap { dropForks(client: client, urls: $0) }
        .flatMap { dropNoProducts(client: client, packageURLs: $0) }
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
                if case let .limited(until: reset) = Github.rateLimitStatus(response) {
                    return eventLoop.makeFailedFuture(AppError.rateLimited(until: reset))
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
