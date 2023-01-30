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
                    completion(.notFound)
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
    case notFound
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



/// Resolve redirects for package urls. In particular, this strips the `.git` extension from the test url, because it would always lead to a redirect. It also normalizes the output to always have a `.git` extension.
/// - Parameters:
///   - eventLoop: EventLoop
///   - url: url to test
///   - timeout: request timeout
/// - Returns: `Redirect`
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
