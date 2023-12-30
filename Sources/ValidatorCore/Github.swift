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
import NIOHTTP1


/// Github specific functionality
enum Github {

    struct Repository: Codable, Equatable {
        let default_branch: String
        let fork: Bool
    }

    static func packageList() throws -> [PackageURL] {
        try JSONDecoder().decode([PackageURL].self,
                                 from: Data(contentsOf: Constants.githubPackageListURL))
    }

}


// MARK: - rate limiting

extension Github {

    enum RateLimitStatus {
        case limited(until: Date)
        case ok(remaining: Int, reset: Date)
        case unknown
    }


    static func rateLimitStatus(_ response: HTTPClient.Response) -> RateLimitStatus {
        guard let remaining = response.headers.first(name: "X-RateLimit-Remaining")
                .flatMap(Int.init),
              let reset = response.headers.first(name: "X-RateLimit-Reset")
                .flatMap(TimeInterval.init)
                .flatMap(Date.init(timeIntervalSince1970:))
        else {
            return .unknown
        }

        if response.status == .forbidden {
            if remaining == 0 {
                return .limited(until: reset)
            } else {
                return .unknown
            }
        }

        return .ok(remaining: remaining, reset: reset)
    }

}


// MARK: - fetching repositories

extension Github {

    struct RateLimit: Decodable {
        var limit: Int
        var used: Int
        var remaining: Int
        var reset: Int

        var resetDate: Date {
            Date(timeIntervalSince1970: TimeInterval(reset))
        }

        var secondsUntilReset: TimeInterval {
            resetDate.timeIntervalSinceNow
        }
    }


    static func getRateLimit(client: HTTPClient, token: String) -> EventLoopFuture<RateLimit> {
        struct Response: Decodable {
            var rate: RateLimit
        }
        let url = URL(string: "https://api.github.com/rate_limit")!
        return ValidatorCore.fetch(Response.self, client: client, url: url)
            .map(\.rate)
    }


    static var repositoryCache = Cache<Repository>()


    static func fetchRepository(client: HTTPClient, owner: String, repository: String) -> EventLoopFuture<Repository> {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repository)")!
        if let cached = repositoryCache[Cache.Key(string: url.absoluteString)] {
            return client.eventLoopGroup.next().makeSucceededFuture(cached)
        }
        return ValidatorCore.fetch(Repository.self, client: client, url: url)
            .flatMapError { error in
                let eventLoop = client.eventLoopGroup.next()
                if case AppError.requestFailed(_, 404) = error {
                    return eventLoop.makeFailedFuture(
                        AppError.repositoryNotFound(owner: owner, name: repository)
                    )
                }
                return eventLoop.makeFailedFuture(error)
            }
            .map { repo in
                repositoryCache[Cache.Key(string: url.absoluteString)] = repo
                return repo
            }
    }

    
    static func fetchRepository(client: HTTPClient, url: PackageURL) async throws-> Repository {
        try await fetchRepository(client: client, url: url, attempt: 0)
    }


    static func fetchRepository(client: HTTPClient, url: PackageURL, attempt: Int) async throws-> Repository {
        guard attempt < 3 else { throw AppError.retryLimitExceeded }
        let apiURL = URL(string: "https://api.github.com/repos/\(url.owner)/\(url.repository)")!
        let key = Cache<Repository>.Key(string: apiURL.absoluteString)
        if let cached = repositoryCache[key] { return cached }
        do {
            let repo = try await fetch(Repository.self, client: client, url: apiURL)
            repositoryCache[key] = repo
            return repo
        } catch let AppError.rateLimited(until: retryDate) {
            let delay = UInt64(retryDate.timeIntervalSinceNow)
            try await Task.sleep(nanoseconds: NSEC_PER_SEC * delay)
            return try await fetchRepository(client: client, url: url, attempt: attempt + 1)
        } catch let AppError.requestFailed(_, code) where code == 404 {
            throw AppError.repositoryNotFound(owner: url.owner, name: url.repository)
        }
    }


    /// Fetch repositories for a collection of package urls. Repository is `nil` for package urls that are not found (404).
    /// - Parameters:
    ///   - client: http client
    ///   - urls: list of package urls
    /// - Returns: list of `(PackageURL, Repository?)` pairs
    static func fetchRepositories(client: HTTPClient, urls: [PackageURL]) -> EventLoopFuture<[(PackageURL, Repository?)]> {
        let req: [EventLoopFuture<(PackageURL, Repository?)>] = urls.map { url -> EventLoopFuture<(PackageURL, Repository?)> in
            Current.fetchRepository(client, url.owner, url.repository)
                .map { (url, $0) }
                .flatMapError { error -> EventLoopFuture<(PackageURL, Repository?)> in
                    // convert 'repository not found' into nil value
                    if case AppError.repositoryNotFound = error {
                        return client.eventLoopGroup.next().makeSucceededFuture((url, nil))
                    }
                    return client.eventLoopGroup.next().makeFailedFuture(error)
                }
        }
        return EventLoopFuture.whenAllSucceed(req, on: client.eventLoopGroup.next())
    }

    static func fetch<T: Decodable>(_ type: T.Type, client: HTTPClient, url: URL) async throws -> T {
        let body = try await Current.fetch(client, url).get()
        do {
            return try JSONDecoder().decode(type, from: body)
        } catch {
            let json = body.getString(at: 0, length: body.readableBytes) ?? "(nil)"
            throw AppError.decodingError(context: url.absoluteString,
                                         underlyingError: error,
                                         json: json)
        }
    }

    static func fetch(client: HTTPClient, url: URL) -> EventLoopFuture<ByteBuffer> {
        let eventLoop = client.eventLoopGroup.next()
        guard let token = Current.githubToken() else {
            return eventLoop.makeFailedFuture(AppError.githubTokenNotSet)
        }
        let headers = HTTPHeaders([
            ("User-Agent", "SPI-Validator"),
            ("Authorization", "Bearer \(token)")
        ])
        let rateLimitHeadroom = 20

        do {
            let request = try HTTPClient.Request(url: url, method: .GET, headers: headers)
            return client.execute(request: request)
                .flatMap { response in
                    switch Github.rateLimitStatus(response) {
                        case let .limited(until: reset):
                            return eventLoop.makeFailedFuture(AppError.rateLimited(until: reset))
                        case let .ok(remaining: remaining, reset: reset) where remaining < rateLimitHeadroom:
                            return eventLoop.makeFailedFuture(AppError.rateLimited(until: reset))
                        case .ok, .unknown:
                            break
                    }
                    guard (200...299).contains(response.status.code) else {
                        return eventLoop.makeFailedFuture(
                            AppError.requestFailed(url, response.status.code)
                        )
                    }
                    guard let body = response.body else {
                        return eventLoop.makeFailedFuture(AppError.noData(url))
                    }
                    return eventLoop.makeSucceededFuture(body)
                }
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }

}
