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
                                         waitIfRateLimited: true)
                }
                .mergingAdditions(with: inputURLs)
                .sorted(by: { $0.lowercased() < $1.lowercased() })

            if let path = output {
                try Current.fileManager.saveList(updated, path: path)
            }
        }
    }
}


func resolvePackageRedirects(eventLoop: EventLoop, urls: [PackageURL]) -> EventLoopFuture<[PackageURL]> {
    EventLoopFuture.whenAllSucceed(
        urls.map {
            resolvePackageRedirects(eventLoop: eventLoop, for: $0)
                .map(\.url)
        },
        on: eventLoop
    )
}


func dropForks(client: HTTPClient, urls: [PackageURL]) -> EventLoopFuture<[PackageURL]> {
    Github.fetchRepositories(client: client, urls: urls)
        .map { pairs in
            pairs.filter { (url, repo) in
                guard let repo = repo else { return false }
                return !repo.fork
            }
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


func findDependencies(packageURL: PackageURL, waitIfRateLimited: Bool) throws -> [PackageURL] {
    try Retry.attempt("Finding dependencies", retries: 3) {
        do {
            let client = HTTPClient(eventLoopGroupProvider: .createNew)
            defer { try? client.syncShutdown() }
            return try findDependencies(client: client, url: packageURL).wait()
        } catch AppError.rateLimited(until: let reset) where waitIfRateLimited {
            print("RATE LIMITED")
            print("rate limit will reset at \(reset)")
            let delay = UInt32(max(0, reset.timeIntervalSinceNow) + 60)
            print("sleeping for \(delay) seconds ...")
            fflush(stdout)
            sleep(delay)
            print("now: \(Date())")
            throw AppError.rateLimited(until: reset)
        } catch {
            print("ERROR: \(error)")
            throw error
        }
    }
}


func findDependencies(client: HTTPClient, url: PackageURL) throws -> EventLoopFuture<[PackageURL]> {
    let el = client.eventLoopGroup.next()
    print("Dependencies for \(url.absoluteString) ...")
    return Package.getManifestURL(client: client, packageURL: url)
        .flatMapThrowing {
            try Package.decode(from: $0)
                .dependencies
                .filter { $0.url.scheme == "https" }
                .filter { $0.url.host?.lowercased() == "github.com" }
                .map { $0.url.addingGitExtension() }
        }
        .flatMapError { error in
            if case AppError.dumpPackageError = error {
                print("INFO: package dump failed: \(error)")
                return el.makeSucceededFuture([])
            }
            return el.makeFailedFuture(error)
        }
        .flatMap { resolvePackageRedirects(eventLoop: el, urls: $0) }
        .flatMap { dropForks(client: client, urls: $0) }
        .flatMap { dropNoProducts(client: client, packageURLs: $0) }
        .map { urls in
            urls.forEach {
                print("  - \($0.absoluteString)")
            }
            fflush(stdout)
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
                guard (200...299).contains(response.status.code) else {
                    return eventLoop.makeFailedFuture(
                        AppError.requestFailed(url, response.status.code)
                    )
                }
                guard let body = response.body else {
                    return eventLoop.makeFailedFuture(AppError.noData(url))
                }
                do {
                    let content = try JSONDecoder().decode(type, from: body)
                    return eventLoop.makeSucceededFuture(content)
                } catch {
                    let json = body.getString(at: 0, length: body.readableBytes) ?? "(nil)"
                    return eventLoop.makeFailedFuture(
                        AppError.decodingError(context: url.absoluteString,
                                               underlyingError: error,
                                               json: json))
                }
            }
    } catch {
        return eventLoop.makeFailedFuture(error)
    }
}
