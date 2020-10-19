import AsyncHTTPClient
import Foundation
import NIO


enum Redirect {
    case initial(PackageURL)
    case notFound(URL)
    case redirected(to: PackageURL)

    var url: PackageURL? {
        switch self {
            case .initial(let url):
                return url
            case .notFound:
                return nil
            case .redirected(to: let url):
                return url
        }
    }
}


func resolveRedirects(client: HTTPClient, for url: PackageURL) -> EventLoopFuture<Redirect> {
    var lastResult = Redirect.initial(url)
    var hopCount = 0
    let maxHops = 10

    func _resolveRedirects(client: HTTPClient, for url: PackageURL) -> EventLoopFuture<Redirect> {
        do {
            let request = try HTTPClient.Request(url: url.rawValue, method: .HEAD)
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
                            return el.makeSucceededFuture(.notFound(url.rawValue))
                        case 429:
                            print("RATE LIMITED")
                            dump(response)
                            fflush(stdout)
                            fallthrough
                        default:
                            return el.makeFailedFuture(
                                AppError.runtimeError("unexpected status '\(response.status.code)' for url: \(url.absoluteString)")
                            )
                    }
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
                case .initial:
                    return .initial(url)
                case .notFound:
                    return $0
                case .redirected(to: let url):
                    return .redirected(to: url.addingGitExtension())
            }
        }
}
