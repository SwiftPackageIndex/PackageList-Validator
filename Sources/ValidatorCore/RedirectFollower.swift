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

import AsyncHTTPClient
import NIO


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



func resolveRedirects(for url: PackageURL) async throws -> Redirect {
    let client = HTTPClient(eventLoopGroupProvider: .singleton,
                            configuration: .init(redirectConfiguration: .disallow))
    defer { try? client.syncShutdown() }
    return try await resolveRedirects(client: client, for: url).get()
}


private func resolveRedirects(client: HTTPClient, for url: PackageURL) -> EventLoopFuture<Redirect> {
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

