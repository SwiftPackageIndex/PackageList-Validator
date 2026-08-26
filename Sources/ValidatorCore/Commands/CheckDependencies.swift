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

    @Option(name: .shortAndLong, help: "stop after fetching this many candidates")
    var limit: Int = .max

    @Option(name: .long, help: "existing directory to fetch candidate manifests into, for evaluate_manifests.sh to evaluate")
    var manifestDir: String

    @Option(name: .shortAndLong)
    var maxCheck: Int = .max

    @Argument(help: "package URLs to check")
    var packageUrls: [PackageURL] = []

    @Option(name: .long)
    var spiApiToken: String

    public func run() async throws {
        let start = Date()
        defer { print("Elapsed (/min):", Date().timeIntervalSince(start)/60) }

        let handover = ManifestHandover(root: manifestDir)
        let packageList = UniqueCanonicalPackageURLs(try inputSource.packageURLs())

        // fetch all dependencies
        let api = SwiftPackageIndexAPI(baseURL: apiBaseURL, apiToken: spiApiToken)
        let records = try await Current.fetchDependencies(api)
        print("Total packages (server):", records.count)
        print("Total packages (input):", packageList.count)

        let allDependencies = records.allDependencies
        let missing = allDependencies.subtracting(packageList)
        print("Not indexed:", missing.count)

        try await HTTPClient.with(configuration: .init(redirectConfiguration: .disallow)) { client in
            var candidates = 0
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

                guard let repo = try? await Current.fetchRepository(client, resolved) else {
                    print("  ... ⛔ could not fetch repository")
                    continue
                }

                do {  // hand the manifests over to be evaluated elsewhere
                    let directory = try handover.prepare(slug: repo.handoverSlug,
                                                         url: resolved.appendingGitExtension())
                    try await Current.fetchManifests(client, repo, directory)
                } catch {
                    print("  ... ⛔ \(error)")
                    // A partly fetched package would otherwise be evaluated and added on the
                    // strength of whichever manifests happened to arrive.
                    try? handover.discard(slug: repo.handoverSlug)
                    continue
                }

                candidates += 1
                print("📦 CANDIDATE (\(candidates)):", resolved.appendingGitExtension())
                if candidates >= limit {
                    print("  ... limit reached.")
                    break
                }
            }

            print("Candidates for evaluation:", candidates)
            print("Now evaluate \(manifestDir), then run add-validated-dependencies over it.")
        }
    }

    public init() { }
}


extension CheckDependencies {
    var inputSource: InputSource { .init(input: input, packageURLs: packageUrls) }
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
