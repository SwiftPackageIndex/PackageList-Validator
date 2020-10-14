import ArgumentParser
import Foundation
import NIO


extension Validator {
    struct CheckRedirects: ParsableCommand {
        @Option(name: .shortAndLong, help: "limit number of urls to check")
        var limit: Int?

        @Option(name: .shortAndLong, help: "save changes to output file")
        var output: String?

        @Argument(help: "Package urls to check")
        var packageUrls: [URL] = []

        @Flag(name: .long, help: "check redirects of canonical package list")
        var usePackageList = false

        func validate() throws {
            guard
                usePackageList || !packageUrls.isEmpty,
                !(usePackageList && !packageUrls.isEmpty) else {
                throw ValidationError("Specify either a list of packages or --usePackageList")
            }
        }

        mutating func run() throws {
            packageUrls = usePackageList
                ? try Github.packageList()
                : packageUrls

            if let limit = limit {
                packageUrls = Array(packageUrls.prefix(limit))
            }

            print("Checking for redirects (\(packageUrls.count) packages) ...")
            let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            let updated = try packageUrls.map { packageURL -> URL in
                switch try resolvePackageRedirects(eventLoop: elg.next(), for: packageURL).wait() {
                    case .initial:
                        return packageURL
                    case .redirected(let url):
                        print("↦  \(packageURL) -> \(url)")
                        return url
                }
            }
            .deletingDuplicates()
            .sorted(by: { $0.absoluteString.lowercased() < $1.absoluteString.lowercased() })

            if let path = output {
                try Current.fileManager.saveList(updated, path: path)
            }
        }
    }
}
