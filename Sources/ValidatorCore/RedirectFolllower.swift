import Foundation
import NIO


class RedirectFollower: NSObject, URLSessionTaskDelegate {
    var status: Redirect
    var session: URLSession?
    var task: URLSessionDataTask?

    init(initialURL: PackageURL, completion: @escaping (Redirect) -> Void) {
        self.status = .initial(initialURL)
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.task = session?.dataTask(with: initialURL.rawValue) { [weak self] (_, response, error) in
            guard error == nil else {
                completion(.error(error!))
                return
            }
            let response = response as! HTTPURLResponse
            guard response.statusCode != 404 else {
                completion(.notFound)
                return
            }
            guard response.statusCode != 429 else {
                let delay = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
                    ?? 60
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


enum Redirect {
    case initial(PackageURL)
    case error(Error)
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
                        return eventLoop.makeSucceededFuture(.redirected(to: url.addingGitExtension()))
                }
            }
    }

    return _resolvePackageRedirects(eventLoop: eventLoop, for: url)
}
