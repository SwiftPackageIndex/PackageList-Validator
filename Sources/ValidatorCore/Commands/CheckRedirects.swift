// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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
    struct CheckRedirects: AsyncParsableCommand {
        @Option(name: .shortAndLong, help: "number of checks to run in parallel")
        var concurrency: Int?

        @Option(name: .shortAndLong, help: "read input from file")
        var input: String?

        @Option(name: .shortAndLong, help: "limit number of urls to check")
        var limit: Int?

        @Option(name: .long, help: "start processing URLs from <offset>")
        var offset: Int = 0

        @Option(name: .shortAndLong, help: "output file for added packages")
        var outputAdded: String?

        @Option(name: .shortAndLong, help: "output file for removed packages")
        var outputRemoved: String?

        @Flag(name: .long, help: "check redirects of canonical package list")
        var usePackageList = false

        @Flag(name: .long, help: "enable detailed logging")
        var verbose = false

        @Option(name: .long, help: "index of chunk to process (0..<number-of-chunks)")
        var chunk: Int?

        @Option(name: .long, help: "number of chunks to split the package list into")
        var numberOfChunks: Int?

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

        static var normalizedPackageURLs = NormalizedPackageURLs(inputURLs: [])

        enum Change: Equatable {
            case add(PackageURL)
            case keep(PackageURL)
            case remove(PackageURL)

            var added: PackageURL? {
                switch self {
                    case let .add(url):
                        return url
                    case .keep, .remove:
                        return nil
                }
            }

            var removed: PackageURL? {
                switch self {
                    case let .remove(url):
                        return url
                    case .add, .keep:
                        return nil
                }
            }
        }

        static func process(redirect: Redirect,
                            verbose: Bool,
                            index: Int,
                            packageURL: PackageURL) async throws -> Change {
            if verbose || index % 50 == 0 {
                print("package \(index) ...")
                fflush(stdout)
            }
            switch redirect {
                case .initial:
                    if verbose {
                        print("        \(packageURL.absoluteString)")
                    }
                    return .keep(packageURL)
                case let .error(error):
                    print("ERROR: \(packageURL.absoluteString) \(error) (ignored, keeping package)")
                    // don't skip packages that have unrecognised errors
                    return .keep(packageURL)
                case .notFound:
                    print("package \(index) ...")
                    print("NOT FOUND: \(packageURL.absoluteString) (deleting package)")
                    return .remove(packageURL)
                case .rateLimited:
                    fatalError("rate limited - should have been retried at a lower level")
                case .redirected(let url):
                    if await normalizedPackageURLs.insert(url).inserted {
                        print("ADD \(packageURL) -> \(url) (new)")
                        return .add(url)
                    } else {
                        print("DELETE \(packageURL) -> \(url) (exists)")
                        return .remove(packageURL)
                    }
                case .unauthorized:
                    print("package \(index) ...")
                    print("UNAUTHORIZED: \(packageURL.absoluteString) (deleting package)")
                    return .remove(packageURL)
            }
        }

        func run() async throws {
            let start = Date()
            defer {
                let elapsed = Date().timeIntervalSince(start)
                if elapsed < 120 {
                    print("Elapsed (/s):", elapsed)
                } else {
                    print("Elapsed (/min):", elapsed/60)
                }
            }

            let verbose = verbose
            let inputURLs = try inputSource.packageURLs()
            let prefix = limit ?? inputURLs.count
            let httpClient = HTTPClient(eventLoopGroupProvider: .singleton,
                                        configuration: .init(redirectConfiguration: .disallow))
            defer { try? httpClient.syncShutdown() }

            let offset = min(offset, inputURLs.count - 1)

            print("Checking for redirects (\(prefix) packages) ...")
            if let chunk = chunk, let numberOfChunks = numberOfChunks {
                print("Chunk \(chunk) of \(numberOfChunks)")
            }

            Self.normalizedPackageURLs = .init(inputURLs: inputURLs)

            let semaphore = Semaphore(maximum: concurrency ?? 1)

            let changes = try await withThrowingTaskGroup(of: Change.self) { group in
                for (index, packageURL) in inputURLs[offset...]
                    .prefix(prefix)
                    .chunk(index: chunk, of: numberOfChunks)
                    .enumerated() {
                    await semaphore.increment()
                    try? await semaphore.waitForAvailability()
                    group.addTask {
                        let index = index + offset
                        let redirect = try await resolvePackageRedirects(client: httpClient, for: packageURL)

                        if index % 100 == 0, let token = Current.githubToken() {
                            let rateLimit = try await Github.getRateLimit(client: httpClient, token: token).get()
                            if rateLimit.remaining < 200 {
                                print("Rate limit remaining: \(rateLimit.remaining)")
                                print("Sleeping until reset at \(rateLimit.resetDate) ...")
                                sleep(UInt32(rateLimit.secondsUntilReset + 0.5))
                            }
                        }

                        let res =  try await Self.process(redirect: redirect,
                                                          verbose: verbose,
                                                          index: index,
                                                          packageURL: packageURL)

                        await semaphore.decrement()
                        return res
                    }
                }
                return try await group.reduce(into: [], { res, next in res.append(next) })
            }

            if let path = outputAdded {
                try Current.fileManager.saveList(changes.compactMap(\.added), path: path)
            }

            if let path = outputRemoved {
                try Current.fileManager.saveList(changes.compactMap(\.removed), path: path)
            }
        }
    }
}
