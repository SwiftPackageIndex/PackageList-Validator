import ArgumentParser
import Foundation
import NIO


extension Validator {
    struct CheckRedirects: ParsableCommand {
        @Argument(help: "Package urls to check")
        var packageUrls: [URL]

        mutating func run() throws {
            print("Checking for redirects ...")
            let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            try packageUrls.forEach { packageURL in
                switch try resolveRedirects(eventLoop: elg.next(), for: packageURL).wait() {
                    case .initial:
                        print("•  \(packageURL) unchanged")
                    case .redirected(let url):
                        print("↦  \(packageURL) -> \(url)")
                }
            }
        }
    }
}
