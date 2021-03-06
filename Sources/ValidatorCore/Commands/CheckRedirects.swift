import ArgumentParser
import Foundation
import NIO


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

        @Flag(name: .long, help: "enable detailed logging")
        var verbose = false

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
            let inputURLs = try inputSource.packageURLs()
            let prefix = limit ?? inputURLs.count

            print("Checking for redirects (\(prefix) packages) ...")

            let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            var normalized = inputURLs.map { $0.normalized() }
            let updated = try inputURLs
                .prefix(prefix)
                .enumerated()
                .compactMap { (index, packageURL) -> PackageURL? in
                    if verbose || index % 50 == 0 {
                        print("package \(index) ...")
                        fflush(stdout)
                    }
                    switch try resolvePackageRedirects(eventLoop: elg.next(),
                                                       for: packageURL).wait() {
                        case .initial:
                            if verbose {
                                print("        \(packageURL.absoluteString)")
                            }
                            return packageURL
                        case let .error(error):
                            print("ERROR: \(error)")
                            throw error
                        case .notFound:
                            print("package \(index) ...")
                            print("NOT FOUND:  \(packageURL.absoluteString)")
                            return nil
                        case .rateLimited:
                            fatalError("rate limited - should have been retried at a lower level")
                        case .redirected(let url):
                            guard !normalized.contains(url.normalized()) else {
                                print("DELETE  \(packageURL) -> \(url) (exists)")
                                return nil
                            }
                            print("ADD     \(packageURL) -> \(url) (new)")
                            normalized.append(url.normalized())
                            return url
                    }
                }
                .sorted(by: { $0.lowercased() < $1.lowercased() })

            if let path = output {
                try Current.fileManager.saveList(updated, path: path)
            }
        }
    }
}
