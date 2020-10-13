import ArgumentParser
import Foundation
import NIO


enum InputSource {
    case file(String)
    case invalid
    case packageList
    case packageURLs([PackageURL])
}


extension Validator {
    struct CheckRedirects: ParsableCommand {
        @Option(name: .shortAndLong, help: "limit number of urls to check")
        var limit: Int?

        @Option(name: .shortAndLong, help: "read input from file")
        var input: String?

        @Option(name: .shortAndLong, help: "save changes to output file")
        var output: String?

        @Argument(help: "Package urls to check")
        var packageUrls: [PackageURL] = []

        @Flag(name: .long, help: "check redirects of canonical package list")
        var usePackageList = false

        var inputSource: InputSource {
            switch (input, usePackageList, packageUrls.count) {
                case (.some(let fname), false, 0):
                    return .file(fname)
                case (.none, true, 0):
                    return .packageList
                case (.none, false, 1...):
                    return .packageURLs(packageUrls)
                default:
                    return .invalid
            }
        }

        func validate() throws {
            if case .invalid = inputSource {
                throw ValidationError("Specify either an input file (--input), --usePackageList, or a list of package URLs")
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
            let updated = try packageUrls.map { packageURL in
                switch try resolvePackageRedirects(eventLoop: elg.next(), for: packageURL).wait() {
                    case .initial:
                        return packageURL
                    case .redirected(let url):
                        print("↦  \(packageURL) -> \(url)")
                        return url
                }
            }
            .deletingDuplicates()
            .sorted(by: { $0.lowercased() < $1.lowercased() })

            if let path = output {
                try Current.fileManager.saveList(updated, path: path)
            }
        }
    }
}
