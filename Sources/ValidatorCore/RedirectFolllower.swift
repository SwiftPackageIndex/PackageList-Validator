import Foundation
import NIO


class RedirectFollower: NSObject, URLSessionDataDelegate {
    var status: Redirect = .initial
    var session: URLSession?
    var task: URLSessionDataTask?

    init(initialURL: URL, completion: @escaping (Redirect) -> Void) {
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
    case initial
    case redirected(to: URL)
}


public func resolveRedirects(eventLoop: EventLoop, for url: URL, timeout: TimeInterval = 10) -> EventLoopFuture<Redirect> {
    let promise = eventLoop.next().makePromise(of: Redirect.self)

    let _ = RedirectFollower(initialURL: url) { result in
        promise.succeed(result)
    }

    return promise.futureResult
}
