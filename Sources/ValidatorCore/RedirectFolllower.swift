import Foundation
import NIO


class RedirectFollower: NSObject, URLSessionDataDelegate {
    var status: Redirect
    var session: URLSession?
    var task: URLSessionDataTask?

    init(initialURL: URL, completion: @escaping (Redirect) -> Void) {
        self.status = .initial(initialURL)
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.task = session?.dataTask(with: initialURL) { [weak self] (_, response, error) in
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
            self.status = .redirected(to: newURL)
        }
        completionHandler(request)
    }
}


public enum Redirect {
    case initial(URL)
    case redirected(to: URL)

    var url: URL {
        switch self {
            case .initial(let url):
                return url
            case .redirected(to: let url):
                return url
        }
    }
}


public func resolveRedirects(eventLoop: EventLoop, for url: URL, timeout: TimeInterval = 10) -> EventLoopFuture<Redirect> {
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
public func resolvePackageRedirects(eventLoop: EventLoop, for url: URL, timeout: TimeInterval = 10) -> EventLoopFuture<Redirect> {
    resolveRedirects(eventLoop: eventLoop, for: url.deletingGitExtension(), timeout: timeout)
        .map {
            switch $0 {
                case .initial:
                    return .initial(url)
                case .redirected(to: let url):
                    return .redirected(to: url.addingGitExtension())
            }
        }
}
