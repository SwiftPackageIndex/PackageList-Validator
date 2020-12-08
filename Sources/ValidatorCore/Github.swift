import AsyncHTTPClient
import Foundation
import NIO
import NIOHTTP1


/// Github specific functionality
enum Github {

    struct DefaultBranchRef: Codable, Equatable {
        var name: String
    }

    struct Repository: Codable, Equatable {
        var defaultBranch: String? { defaultBranchRef?.name }
        var defaultBranchRef: DefaultBranchRef?
        var isFork: Bool

        struct Response: Decodable, Equatable {
            struct Result: Decodable, Equatable {
                var repository: Repository?
            }
            var data: Result
            var errors: [GraphQL.Error]?
        }
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


    static func fetchRepository(client: HTTPClient, owner: String, repository: String) -> EventLoopFuture<Repository> {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repository)")!
        if let cached = repositoryCache[Cache.Key(string: url.absoluteString)] {
            return client.eventLoopGroup.next().makeSucceededFuture(cached)
        }

        let query = GraphQL.Query(query: """
                {
                  repository(name: "\(repository)", owner: "\(owner)") {
                    defaultBranchRef {
                      name
                    }
                    isFork
                  }
                }
                """)

        return fetchResource(Repository.Response.self,
                             client: client,
                             query: query)
            .flatMapError { error in
                let eventLoop = client.eventLoopGroup.next()
                if case AppError.requestFailed(_, 404) = error {
                    return eventLoop.makeFailedFuture(
                        AppError.repositoryNotFound(owner: owner, name: repository)
                    )
                }
                return eventLoop.makeFailedFuture(error)
            }
            .flatMapThrowing { response in
                guard let repo = response.data.repository else {
                    throw AppError.repositoryNotFound(owner: owner, name: repository)
                }
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
            fetchRepository(client: client, owner: url.owner, repository: url.repository)
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


// MARK: - GraphQL

extension Github {

    static let graphQLApiUrl = "https://api.github.com/graphql"

    enum GraphQL {
        struct Query: Codable {
            var query: String
        }

        enum ErrorType: String, Decodable, Equatable {
            case notFound = "NOT_FOUND"
        }

        struct Location: Decodable, Equatable {
            var line: Int
            var column: Int
        }

        struct Error: Decodable, Equatable {
            var type: ErrorType
            var path: [String]
            var locations: [Location]
            var message: String
        }
    }

    static func fetchResource<T: Decodable>(_ type: T.Type,
                                            client: HTTPClient,
                                            query: GraphQL.Query) -> EventLoopFuture<T> {
        let eventLoop = client.eventLoopGroup.next()
        let url = URL(string: graphQLApiUrl)!

        let headers = HTTPHeaders([
            ("User-Agent", "SPI-Validator"),
            Current.githubToken().map { ("Authorization", "Bearer \($0)") }
        ].compactMap({ $0 }))

        do {
            let body: HTTPClient.Body = .data(try JSONEncoder().encode(query))
            let request = try HTTPClient.Request(url: graphQLApiUrl,
                                                 method: .POST,
                                                 headers: headers,
                                                 body: body)
            return client.execute(request: request)
                .flatMap { response -> EventLoopFuture<T> in
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
                        let content = try JSONDecoder().decode(T.self, from: body)
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

}
