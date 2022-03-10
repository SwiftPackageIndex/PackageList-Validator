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
import NIOHTTP1


enum Redirect {
    case initial(String)
    case error(String)
    case notFound
    case rateLimited(delay: Int)
    case redirected(to: String)
}

extension Redirect {
    var packageURL: PackageURL? {
        switch self {
            case .initial(let url):
                return .init(argument: url)
            case .error, .notFound, .rateLimited:
                return nil
            case .redirected(to: let url):
                return .init(argument: url)
        }
    }
}


enum RedirectFollower {
    struct Client {
        private var client: HTTPClient

        init() {
            client = HTTPClient(eventLoopGroupProvider: .createNew,
                                configuration: .init(redirectConfiguration: .disallow))
        }

        func execute(request: HTTPClient.Request, deadline: NIODeadline? = nil) -> EventLoopFuture<HTTPClient.Response> {
            client.execute(request: request, deadline: deadline)
        }

        func syncShutdown() throws {
            try client.syncShutdown()
        }

        var eventLoop: EventLoop { client.eventLoopGroup.next() }
    }

    static func resolve(client: Client, url: String) -> EventLoopFuture<Redirect> {
        do {
            let req = try HTTPClient.Request(url: url, headers: .spiAuth)
            return client.execute(request: req)
                .map { res -> Redirect in
                    guard res.status != .notFound else { return .notFound }
                    guard res.status != .tooManyRequests else {
                        return .rateLimited(delay: res.headers.retryAfter)
                    }
                    if let location = res.headers.first(name: "Location") {
                        return .redirected(to: location)
                    }
                    return .initial(url)
                }
                .flatMapError {
                    client.eventLoop.makeSucceededFuture(.error("\($0)"))
                }
        } catch {
            return client.eventLoop.makeFailedFuture(error)
        }
    }
}


extension HTTPHeaders {
    static var spiAuth: Self {
        var headers = HTTPHeaders.init([("User-Agent", "SPI-Validator")])
        if let token = Current.githubToken() {
            headers.add(name: "Authorization", value: "Bearer \(token)")
        }
        return headers
    }

    var retryAfter: Int {
        first(name: "Retry-After").flatMap(Int.init) ?? 5
    }
}


extension RedirectFollower {
    /// Resolve redirects for package urls. In particular, this strips the `.git` extension from the test url, because it would always lead to a redirect. It also normalizes the output to always have a `.git` extension.
    /// - Parameters:
    ///   - eventLoop: EventLoop
    ///   - url: url to test
    ///   - timeout: request timeout
    /// - Returns: `Redirect`
    static func resolvePackageRedirects(client: RedirectFollower.Client,
                                        url: PackageURL) -> EventLoopFuture<Redirect> {
        let maxDepth = 10
        var depth = 0

        func _resolvePackageRedirects(client: RedirectFollower.Client,
                                      url: PackageURL) -> EventLoopFuture<Redirect> {
            RedirectFollower.resolve(client: client,
                                     url: url.deletingGitExtension().absoluteString)
                .flatMap { status -> EventLoopFuture<Redirect> in
                    switch status {
                        case .error, .initial, .notFound:
                            return client.eventLoop.makeSucceededFuture(status)
                        case .rateLimited(let delay):
                            guard depth < maxDepth else {
                                return client.eventLoop.makeFailedFuture(
                                    AppError.runtimeError("recursion limit exceeded")
                                )
                            }
                            depth += 1
                            print("RATE LIMITED")
                            print("sleeping for \(delay)s ...")
                            fflush(stdout)
                            sleep(UInt32(delay))
                            return resolvePackageRedirects(client: client, url: url)
                        case .redirected(to: let url):
                            return client.eventLoop.makeSucceededFuture(.redirected(to: url.appendingGitExtension()))
                    }
                }
        }

        return _resolvePackageRedirects(client: client, url: url)
    }
}


extension String {
    func appendingGitExtension() -> Self {
        lowercased().hasSuffix(".git") ? self : self + ".git"
    }
}
