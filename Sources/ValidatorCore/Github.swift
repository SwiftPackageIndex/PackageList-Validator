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


/// Github specific functionality
enum Github {

    struct Repository: Codable {
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

    static var repositoryCache = Cache<Repository>()

    struct RateLimit: Decodable {
        var limit: Int
        var used: Int
        var remaining: Int
        var reset: Int
    }

    static func getRateLimit(client: HTTPClient, token: String) -> EventLoopFuture<RateLimit> {
        struct Response: Decodable {
            var rate: RateLimit
        }
        let url = URL(string: "https://api.github.com/rate_limit")!
        return fetch(Response.self, client: client, url: url)
            .map(\.rate)
    }

    static func fetchRepository(client: HTTPClient, owner: String, repository: String) -> EventLoopFuture<Repository> {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repository)")!
        if let cached = repositoryCache[Cache.Key(string: url.absoluteString)] {
            return client.eventLoopGroup.next().makeSucceededFuture(cached)
        }
        return fetch(Repository.self, client: client, url: url)
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

}
