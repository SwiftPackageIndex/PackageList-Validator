// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArgumentParser
import Foundation
import NIO
import AsyncHTTPClient


extension Validator {
    struct CheckRedirects: ParsableCommand {
        @Option(name: .shortAndLong, help: "read input from file")
        var input: String?

        @Option(name: .shortAndLong, help: "limit number of urls to check")
        var limit: Int?
        
        @Option(name: .long, help: "start processing URLs from <offset>")
        var offset: Int = 0

        @Option(name: .shortAndLong, help: "save changes to output file")
        var output: String?

        @Flag(name: .long, help: "check redirects of canonical package list")
        var usePackageList = false

        @Flag(name: .long, help: "enable detailed logging")
        var verbose = false

        @Argument(help: "Package urls to check")
        var packageUrls: [PackageURL] = []

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

        static func process(redirect: Redirect,
                            verbose: Bool,
                            index: Int,
                            packageURL: PackageURL,
                            normalized: inout Set<String>) throws -> PackageURL? {
            if verbose || index % 50 == 0 {
                print("package \(index) ...")
                fflush(stdout)
            }
            switch redirect {
                case .initial:
                    if verbose {
                        print("        \(packageURL.absoluteString)")
                    }
                    return packageURL
                case let .error(error):
                    print("ERROR: \(error)")
                    return nil
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
                    normalized.insert(url.normalized())
                    return url
            }
        }

        mutating func run() throws {
            let verbose = verbose
            let inputURLs = try inputSource.packageURLs()
            let prefix = limit ?? inputURLs.count
            let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
            defer { try? httpClient.syncShutdown() }

            let offset = min(offset, inputURLs.count - 1)

            print("Checking for redirects (\(prefix) packages) ...")

            let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            var normalized = Set(inputURLs.map { $0.normalized() })
            let updated = try inputURLs[offset...]
                .prefix(prefix)
                .enumerated()
                .compactMap { (index, packageURL) -> PackageURL? in
                    let index = index + offset
                    let redirect = try resolvePackageRedirects(eventLoop: elg.next(),
                                                               for: packageURL)
                        .wait()

                    if index % 100 == 0, let token = Current.githubToken() {
                        let rateLimit = try Github.getRateLimit(client: httpClient,
                                                                token: token).wait()
                        if rateLimit.remaining < 200 {
                            print("Rate limit remaining: \(rateLimit.remaining)")
                            print("Sleeping until reset at \(rateLimit.resetDate) ...")
                            sleep(UInt32(rateLimit.secondsUntilReset + 0.5))
                        }
                    }

                    return try Self.process(redirect: redirect,
                                            verbose: verbose,
                                            index: index,
                                            packageURL: packageURL,
                                            normalized: &normalized)
                }
                .sorted(by: { $0.lowercased() < $1.lowercased() })

            if let path = output {
                try Current.fileManager.saveList(updated, path: path)
            }
        }
    }
}
