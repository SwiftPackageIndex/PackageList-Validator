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
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NIO


class RedirectFollower: NSObject, URLSessionTaskDelegate {
    var status: Redirect
    var session: URLSession?
    var task: URLSessionDataTask?

    init(initialURL: PackageURL, completion: @escaping (Redirect) -> Void) {
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
                completion(.error("\(error!)"))
                return
            }
            let response = response as! HTTPURLResponse
            switch response.statusCode {
                case 401, 403:
                    completion(.unauthorized)
                case 404:
                    completion(.notFound(initialURL))
                case 429:
                    let delay = response.value(forHTTPHeaderField: "Retry-After")
                        .flatMap(Int.init) ?? 5
                    completion(.rateLimited(delay: delay))
                default:
                    completion(self!.status)
            }
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


enum Redirect: Equatable {
    case initial(PackageURL)
    case error(String)
    case notFound(PackageURL)
    case rateLimited(delay: Int)
    case redirected(to: PackageURL)
    case unauthorized

    var url: PackageURL? {
        switch self {
            case .initial(let url):
                return url
            case .error, .notFound, .rateLimited, .unauthorized:
                return nil
            case .redirected(to: let url):
                return url
        }
    }
}


func resolveRedirects(eventLoop: EventLoop, for url: PackageURL) -> EventLoopFuture<Redirect> {
    let promise = eventLoop.next().makePromise(of: Redirect.self)

    let _ = RedirectFollower(initialURL: url) { result in
        promise.succeed(result)
    }

    return promise.futureResult
}


func resolveRedirects(for url: PackageURL) async -> Redirect {
    await withCheckedContinuation { continuation in
        let _ = RedirectFollower(initialURL: url) {
            continuation.resume(returning: $0)
        }
    }
}


/// Resolve redirects for package urls. In particular, this strips the `.git` extension from the test url, because it would always lead to a redirect. It also normalizes the output to always have a `.git` extension.
/// - Parameters:
///   - eventLoop: EventLoop
///   - url: url to test
///   - timeout: request timeout
/// - Returns: `Redirect`
@available(*, deprecated)
func resolvePackageRedirects(eventLoop: EventLoop,
                             for url: PackageURL) -> EventLoopFuture<Redirect> {
    let maxDepth = 10
    var depth = 0

    func _resolvePackageRedirects(eventLoop: EventLoop,
                                  for url: PackageURL) -> EventLoopFuture<Redirect> {
        resolveRedirects(eventLoop: eventLoop, for: url.deletingGitExtension())
            .flatMap { status -> EventLoopFuture<Redirect> in
                switch status {
                    case .initial, .notFound, .error, .unauthorized:
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


// MARK: - new

import AsyncHTTPClient

func resolveRedirects(client: HTTPClient, for url: PackageURL) -> EventLoopFuture<Redirect> {
    var lastResult = Redirect.initial(url)
    var hopCount = 0
    let maxHops = 10

    func _resolveRedirects(client: HTTPClient, for url: PackageURL) -> EventLoopFuture<Redirect> {
        do {
            var request = try HTTPClient.Request(url: url.rawValue, method: .HEAD, headers: .init([
                ("User-Agent", "SPI-Validator")
            ]))
            if let token = Current.githubToken() {
                request.headers.add(name: "Authorization", value: "Bearer \(token)")
            }
            return client.execute(request: request)
                .flatMap { response in
                    let el = client.eventLoopGroup.next()
                    switch response.status.code {
                        case 200...299:
                            return el.makeSucceededFuture(lastResult)
                        case 301:
                            guard hopCount < maxHops else {
                                return el.makeFailedFuture(
                                    AppError.runtimeError("max redirects exceeded for url: \(url.absoluteString)")
                                )
                            }
                            guard
                                let redirected = response.headers["Location"]
                                    .first
                                    .flatMap(URL.init(string:))
                                    .map(PackageURL.init(rawValue:)) else {
                                return el.makeFailedFuture(
                                    AppError.runtimeError("no Location header for url: \(url.absoluteString)")
                                )
                            }
                            lastResult = .redirected(to: redirected)
                            hopCount += 1
                            return _resolveRedirects(client: client, for: redirected)
                        case 404:
                            return el.makeSucceededFuture(.notFound(url))
                        case 429:
                            print("RATE LIMITED")
                            let delay = response.headers["Retry-After"]
                                .first
                                .flatMap(UInt32.init) ?? 60
                            print("Sleeping for \(delay)s ...")
                            sleep(delay)
                            return _resolveRedirects(client: client, for: url)
                        default:
                            return el.makeFailedFuture(
                                AppError.runtimeError("unexpected status '\(response.status.code)' for url: \(url.absoluteString)")
                            )
                    }
                }
                .flatMapError { error in
                    guard let clientError = error as? HTTPClientError,
                          clientError == .remoteConnectionClosed else {
                        return client.eventLoopGroup.next().makeFailedFuture(error)
                    }
                    hopCount += 1
                    let delay = 5
                    print("CONNECTION CLOSED")
                    print("retrying in \(delay)s ...")
                    sleep(5)
                    return _resolveRedirects(client: client, for: url)
                }
        } catch {
            return client.eventLoopGroup.next().makeFailedFuture(error)
        }
    }

    return _resolveRedirects(client: client, for: url)
}



/// Resolve redirects for package urls. In particular, this strips the `.git` extension from the test url, because it would always lead to a redirect. It also normalizes the output to always have a `.git` extension.
/// - Parameters:
///   - eventLoop: EventLoop
///   - url: url to test
///   - timeout: request timeout
/// - Returns: `Redirect`
func resolvePackageRedirects(client: HTTPClient, for url: PackageURL) -> EventLoopFuture<Redirect> {
    resolveRedirects(client: client, for: url.deletingGitExtension())
        .map {
            switch $0 {
                case .initial, .notFound, .error, .unauthorized, .rateLimited:
                    return $0
                case .redirected(to: let url):
                    return .redirected(to: url.appendingGitExtension())
            }
        }
}

