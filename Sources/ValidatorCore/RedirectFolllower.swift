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

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.status = .error(error)
        }
    }
}


enum Redirect {
    case initial(PackageURL)
    case error(Error)
    case redirected(to: PackageURL)

    var url: PackageURL? {
        switch self {
            case .initial(let url):
                return url
            case .error:
                return nil
            case .redirected(to: let url):
                return url
        }
    }
}


// FIXME: clean up
import ShellOut

// TODO: drop future
func resolveRedirects(eventLoop: EventLoop, for url: PackageURL) -> EventLoopFuture<Redirect> {
    let cmd = ShellOutCommand(string: "curl -Ls -o /dev/null -w %{url_effective} \(url.absoluteString)")
    do {
        let result = try Current.shell.run(command: cmd)
        guard let newURL = URL(string: result) else {
            return eventLoop.makeFailedFuture(
                AppError.runtimeError("curl for redirects returned bad url: \(result)")
            )
        }
        let newPackageURL = PackageURL(rawValue: newURL)
        return eventLoop.makeSucceededFuture(
            url.normalized() == newPackageURL.normalized()
                ? .initial(url)
                : .redirected(to: newPackageURL)
        )
    } catch {
        return eventLoop.makeFailedFuture(
            AppError.runtimeError("curl for redirects failed: \(error)")
        )
    }
}



/// Resolve redirects for package urls. In particular, this strips the `.git` extension from the test url, because it would always lead to a redirect. It also normalizes the output to always have a `.git` extension.
/// - Parameters:
///   - eventLoop: EventLoop
///   - url: url to test
///   - timeout: request timeout
/// - Returns: `Redirect`
func resolvePackageRedirects(eventLoop: EventLoop, for url: PackageURL) -> EventLoopFuture<Redirect> {
    resolveRedirects(eventLoop: eventLoop, for: url.deletingGitExtension())
        .map {
            switch $0 {
                case .initial:
                    return .initial(url)
                case .error:
                    return $0
                case .redirected(to: let url):
                    return .redirected(to: url.addingGitExtension())
            }
        }
}
