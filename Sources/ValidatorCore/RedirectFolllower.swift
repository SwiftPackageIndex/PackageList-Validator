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


enum Redirect: Equatable {
    case initial(String)
    case notFound
    case rateLimited(delay: Int)
    case redirected(to: String)
}


func getRedirect(client: HTTPClient, url: String) throws -> Redirect {
    let req = try HTTPClient.Request(url: url, headers: .spiAuth)
    let res = try client.execute(request: req,
                                          deadline: .now() + .seconds(5)).wait()
    guard res.status != .notFound else { return .notFound }
    guard res.status != .tooManyRequests else {
        return .rateLimited(delay: res.headers.retryAfter)
    }
    if let location = res.headers.first(name: "Location") {
        return .redirected(to: location)
    }
    return .initial(url)
}


struct RedirectFollower {
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
    }

    static func resolve(client: Client, url: String) throws -> Redirect {
        let req = try HTTPClient.Request(url: url, headers: .spiAuth)
        let res = try client.execute(request: req,
                                     deadline: .now() + .seconds(5)).wait()
        guard res.status != .notFound else { return .notFound }
        guard res.status != .tooManyRequests else {
            return .rateLimited(delay: res.headers.retryAfter)
        }
        if let location = res.headers.first(name: "Location") {
            return .redirected(to: location)
        }
        return .initial(url)
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


// MARK: - old impl


@available(*, deprecated)
class _RedirectFollower: NSObject, URLSessionTaskDelegate {
    var status: _Redirect
    var session: URLSession?
    var task: URLSessionDataTask?

    init(initialURL: PackageURL, completion: @escaping (_Redirect) -> Void) {
        self.status = .initial(initialURL)
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        var req = URLRequest(url: initialURL.rawValue)
        req.addValue("SPI-Validator", forHTTPHeaderField: "User-Agent")
        if let token = Current.githubToken() {
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        self.task = session?.dataTask(with: req) { [weak self] (_, response, error) in
            guard error == nil else {
                completion(.error(error?.localizedDescription ?? "unknown error"))
                return
            }
            let response = response as! HTTPURLResponse
            guard response.statusCode != 404 else {
                completion(.notFound)
                return
            }
            guard response.statusCode != 429 else {
                let delay = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
                    ?? 5
                completion(.rateLimited(delay: delay))
                return
            }
            completion(self!.status)
        }
        self.task?.resume()
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let newURL = request.url {
            self.status = .redirected(to: PackageURL(rawValue: newURL))
        }
        completionHandler(request)
    }
}


@available(*, deprecated)
enum _Redirect: Equatable {
    case initial(PackageURL)
    case error(String)
    case notFound
    case rateLimited(delay: Int)
    case redirected(to: PackageURL)

    var url: PackageURL? {
        switch self {
            case .initial(let url):
                return url
            case .error, .notFound, .rateLimited:
                return nil
            case .redirected(to: let url):
                return url
        }
    }
}


@available(*, deprecated)
func resolveRedirects(eventLoop: EventLoop, for url: PackageURL) -> EventLoopFuture<_Redirect> {
    let promise = eventLoop.next().makePromise(of: _Redirect.self)

    let _ = _RedirectFollower(initialURL: url) { result in
        promise.succeed(result)
    }

    return promise.futureResult
}



/// Resolve redirects for package urls. In particular, this strips the `.git` extension from the test url, because it would always lead to a redirect. It also normalizes the output to always have a `.git` extension.
/// - Parameters:
///   - eventLoop: EventLoop
///   - url: url to test
///   - timeout: request timeout
/// - Returns: `Redirect`
@available(*, deprecated)
func resolvePackageRedirects(eventLoop: EventLoop,
                             for url: PackageURL) -> EventLoopFuture<_Redirect> {
    let maxDepth = 10
    var depth = 0

    func _resolvePackageRedirects(eventLoop: EventLoop,
                                  for url: PackageURL) -> EventLoopFuture<_Redirect> {
        resolveRedirects(eventLoop: eventLoop, for: url.deletingGitExtension())
            .flatMap { status -> EventLoopFuture<_Redirect> in
                switch status {
                    case .initial, .notFound, .error:
                        return eventLoop.makeSucceededFuture(status)
                    case .rateLimited(let delay):
                        guard depth < maxDepth else {
                            return eventLoop.makeFailedFuture(
                                AppError.runtimeError("recursion limit exceeded")
                            )
                        }
                        depth += 1
                        print("RATE LIMITED")
                        print("sleeping for \(delay)s ...")
                        fflush(stdout)
                        sleep(UInt32(delay))
                        return resolvePackageRedirects(eventLoop: eventLoop, for: url)
                    case .redirected(to: let url):
                        return eventLoop.makeSucceededFuture(.redirected(to: url.appendingGitExtension()))
                }
            }
    }

    return _resolvePackageRedirects(eventLoop: eventLoop, for: url)
}
