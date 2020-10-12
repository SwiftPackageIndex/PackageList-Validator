import ArgumentParser
import Foundation
import NIO


extension Validator {
    struct CheckRedirects: ParsableCommand {
        @Argument(help: "Package urls to check")
        var packageUrls: [URL] = []

        @Flag(name: .long, help: "check redirects of canonical package list")
        var usePackageList = false

        @Option(name: .shortAndLong, help: "limit number of urls to check")
        var limit: Int?

        mutating func run() throws {
            guard
                usePackageList || !packageUrls.isEmpty,
                !(usePackageList && !packageUrls.isEmpty) else {
                throw ValidationError("Specify either a list of packages or --usePackageList")
            }
            packageUrls = usePackageList
                ? try fetchPackageList()
                : packageUrls
            if let limit = limit {
                packageUrls = Array(packageUrls.prefix(limit))
            }
            print("Checking for redirects (\(packageUrls.count) packages) ...")
            let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            try packageUrls.forEach { packageURL in
                // delete git extensions to avoid everything being flagged as a redirect
                let url = packageURL.deletingGitExtension()
                switch try resolveRedirects(eventLoop: elg.next(), for: url).wait() {
                    case .initial:
                        print("•  \(packageURL) unchanged")
                    case .redirected(let url):
                        print("↦  \(packageURL) -> \(url)")
                }
            }
        }
    }
}


func fetchPackageList() throws -> [URL] {
    try JSONDecoder().decode([URL].self,
                             from: Data(contentsOf: Constants.githubPackageListURL))
}
