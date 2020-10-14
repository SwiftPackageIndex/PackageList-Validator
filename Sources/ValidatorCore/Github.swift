import AsyncHTTPClient
import Foundation
import NIO


/// Github specific functionality
enum Github {

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

}


// MARK: - rate limiting

extension Github {

    enum RateLimitStatus {
        case limited(until: Date)
        case ok
        case unknown
    }


    static func rateLimitStatus(_ response: HTTPClient.Response) -> RateLimitStatus {
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

}


// MARK: - fetching repositories

extension Github {

    static var repositoryCache = Cache<Repository>()


    static func fetchRepository(client: HTTPClient, url: URL) -> EventLoopFuture<Repository> {
        let repository = url.deletingPathExtension().lastPathComponent
        let owner = url.deletingLastPathComponent().lastPathComponent
        return fetchRepository(client: client, owner: owner, repository: repository)
    }


    static func fetchRepository(client: HTTPClient, owner: String, repository: String) -> EventLoopFuture<Repository> {
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


    static func fetchRepositories(client: HTTPClient, urls: [URL]) -> EventLoopFuture<[(URL, Repository)]> {
        let req = urls.map { url in
            fetchRepository(client: client, url: url)
                .map { (url, $0) }
        }
        return EventLoopFuture.whenAllSucceed(req, on: client.eventLoopGroup.next())
    }

}
