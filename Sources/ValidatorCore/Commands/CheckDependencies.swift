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

import Foundation

import ArgumentParser
import AsyncHTTPClient
import CanonicalPackageURL


public struct CheckDependencies: AsyncParsableCommand {
    @Option(name: .long)
    var apiBaseURL: String = "https://swiftpackageindex.com"

    @Option(name: .shortAndLong, help: "read input URLs from file")
    var input: String?

    @Option(name: .shortAndLong)
    var limit: Int = .max

    @Option(name: .shortAndLong)
    var maxCheck: Int = .max

    @Option(name: .shortAndLong, help: "save changes to output file")
    var output: String?

    @Argument(help: "package URLs to check")
    var packageUrls: [PackageURL] = []

    @Option(name: .long)
    var spiApiToken: String

    public func run() async throws {
        let start = Date()
        defer { print("Elapsed (/min):", Date().timeIntervalSince(start)/60) }

        let packageList = UniqueCanonicalPackageURLs(try inputSource.packageURLs())

        // fetch all dependencies
        let api = SwiftPackageIndexAPI(baseURL: apiBaseURL, apiToken: spiApiToken)
        let records = try await Current.fetchDependencies(api)
        print("Total packages (server):", records.count)
        print("Total packages (input):", packageList.count)

        let allDependencies = records.allDependencies
        let missing = allDependencies.subtracting(packageList)
        print("Not indexed:", missing.count)

        let client = HTTPClient(eventLoopGroupProvider: .singleton,
                                configuration: .init(redirectConfiguration: .disallow))
        defer { try? client.syncShutdown() }

        var newPackages = UniqueCanonicalPackageURLs()
        for (idx, dep) in missing
            .sorted(by: { $0.packageURL.absoluteString < $1.packageURL.absoluteString })
            .prefix(maxCheck)
            .enumerated() {
            if idx % 10 == 0 {
                print("Progress:", idx, "/", missing.count)
            }
            
            // resolve redirects
            print("Processing:", dep.packageURL, "...")
            guard let resolved = try? await Current.resolvePackageRedirects(client, dep.packageURL).url else {
                // TODO: consider adding retry for some errors
                print("  ... ⛔ redirect resolution returned nil")
                continue
            }
            
            if resolved.canonicalPackageURL.canonicalPath != dep.canonicalPath {
                print("  ... redirected to:", resolved)
            }

            if packageList.contains(resolved.canonicalPackageURL) {
                print("  ... ⛔ already indexed")
                continue
            }

            do {  // run package dump to validate
                let repo = try await Current.fetchRepository(client, resolved)
                _ = try await Current.decodeManifest(client, repo)
            } catch {
                print("  ... ⛔ \(error)")
                continue
            }

            if newPackages.insert(resolved.appendingGitExtension().canonicalPackageURL).inserted {
                print("✅ ADD (\(newPackages.count)):", resolved.appendingGitExtension())
            }
            if newPackages.count >= limit {
                print("  ... limit reached.")
                break
            }
        }

        print("New packages:", newPackages.count)
        for (idx, p) in newPackages
            .sorted()
            .enumerated() {
            print("  ✅ ADD", idx, p)
        }

        // merge with existing and sort result
        let merged = (packageList.map(\.packageURL) + newPackages.map(\.packageURL)).sorted()

        print("Total:", merged.count)

        if let path = output {
            try Current.fileManager.saveList(merged, path: path)
        }
    }

    public init() { }

}


extension CheckDependencies {
    var inputSource: InputSource {
        switch (input, packageUrls.count) {
            case (.some(let fname), 0):
                return .file(fname)
            case (.none, 1...):
                return .packageURLs(packageUrls)
            default:
                return .invalid
        }
    }

    enum InputSource {
        case file(String)
        case invalid
        case packageURLs([PackageURL])

        func packageURLs() throws -> [PackageURL] {
            switch self {
                case .file(let path):
                    let fileURL = URL(fileURLWithPath: path)
                    return try JSONDecoder().decode([PackageURL].self, from: Data(contentsOf: fileURL))
                case .invalid:
                    throw AppError.runtimeError("invalid input source")
                case .packageURLs(let urls):
                    return urls
            }
        }
    }
}


extension [SwiftPackageIndexAPI.PackageRecord] {
    var allDependencies: UniqueCanonicalPackageURLs {
        let deps = flatMap { $0.resolvedDependencies ?? [] }
        return Set(
            deps.map { HashedCanonicalPackageURL($0) }
        )
    }
}


extension CanonicalPackageURL {
    var packageURL: PackageURL { .init(canonicalURL) }
    var canonicalURL: URL { .init(string: "https://\(hostname)/\(path).git")! }
}


extension PackageURL {
    var canonicalPackageURL: CanonicalPackageURL {
        .init(absoluteString)!
    }
}
