import Foundation


class RedirectFollower: NSObject, URLSessionDataDelegate {
    var status: Redirect
    var session: URLSession?
    var task: URLSessionDataTask?

    init(initialURL: URL, completion: @escaping () -> Void) {
        self.status = .initial
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.task = session?.dataTask(with: initialURL) { (_, response, error) in
            completion()
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


public func resolveRedirects(for url: URL, timeout: TimeInterval = 10) -> Redirect {
    let semaphore = DispatchSemaphore(value: 0)

    let follower = RedirectFollower(initialURL: url) {
        semaphore.signal()
    }

    _ = semaphore.wait(timeout: .now() + timeout)

    return follower.status
}
