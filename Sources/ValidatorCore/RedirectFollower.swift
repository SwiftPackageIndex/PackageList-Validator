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

#if os(Linux)
import CDispatch // for NSEC_PER_SEC https://github.com/apple/swift-corelibs-libdispatch/issues/659
#endif


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


private func resolveRedirects(client: Client, for url: PackageURL) async throws -> Redirect {
    var lastResult = Redirect.initial(url)
    var hopCount = 0
    let maxHops = 10

    func _resolveRedirects(client: Client, for url: PackageURL) async throws -> Redirect {
        var request = try HTTPClient.Request(url: url.rawValue, method: .HEAD, headers: .init([
            ("User-Agent", "SPI-Validator")
        ]))
        if let token = Current.githubToken() {
            request.headers.add(name: "Authorization", value: "Bearer \(token)")
        }
        do {
            let response = try await client.execute(request: request).get()
            switch response.status.code {
                case 200...299:
                    return lastResult
                case 301:
                    guard hopCount < maxHops else {
                        throw AppError.runtimeError("max redirects exceeded for url: \(url.absoluteString)")
                    }
                    guard let redirected = response.headers["Location"]
                        .first
                        .flatMap(URL.init(string:))
                        .map(PackageURL.init(rawValue:)) else {
                        throw AppError.runtimeError("no Location header for url: \(url.absoluteString)")
                    }
                    lastResult = .redirected(to: redirected)
                    hopCount += 1
                    return try await _resolveRedirects(client: client, for: redirected)
                case 404:
                    return .notFound(url)
                case 429:
                    print("RATE LIMITED")
                    let delay = response.headers["Retry-After"]
                        .first
                        .flatMap(UInt64.init) ?? 60
                    print("Sleeping for \(delay)s ...")
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC * delay)
                    return try await _resolveRedirects(client: client, for: url)
                case 502: // bad gateway, https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/3734
                    // increment hopCount as a way to limit the number of retries (even though it's
                    // not a true "hop")
                    hopCount += 1
                    let delay: UInt64 = 3
                    print("Sleeping for \(delay)s ...")
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC * delay)
                    return try await _resolveRedirects(client: client, for: url)
                default:
                    throw AppError.runtimeError("unexpected status '\(response.status.code)' for url: \(url.absoluteString)")
            }
        } catch let error as HTTPClientError where error == .remoteConnectionClosed {
            hopCount += 1
            let delay: UInt64 = 5
            print("CONNECTION CLOSED")
            print("retrying in \(delay)s ...")
            try await Task.sleep(nanoseconds: NSEC_PER_SEC * delay)
            return try await _resolveRedirects(client: client, for: url)
        }
    }

    return try await _resolveRedirects(client: client, for: url)
}


func resolvePackageRedirects(client: Client, for url: PackageURL) async throws -> Redirect {
    let res = try await resolveRedirects(client: client, for: url.deletingGitExtension())
    switch res {
        case .initial, .notFound, .error, .unauthorized, .rateLimited:
            return res
        case .redirected(to: let newURL):
            return .redirected(to: newURL.appendingGitExtension())
    }
}
