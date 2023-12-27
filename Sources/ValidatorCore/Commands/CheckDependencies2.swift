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


public struct CheckDependencies2: AsyncParsableCommand {
    @Option(name: .long)
    var apiBaseURL: String = "https://swiftpackageindex.com"

    @Option(name: .shortAndLong)
    var limit: Int = .max

    @Option(name: .long)
    var spiApiToken: String

    public func run() async throws {
        print("check depdendencies 2")

        // CheckDependencies
        // - expandDependencies([PackageURL])
        //   - flatMap
        //     - findDependencies(PackageURL)
        //     - get package manifest
        //     - decode manifest
        //     - package dump
        //     - get dependencies
        //   - resolvePackageRedirects([PackageURL])
        //   - dropForks([PackageURL])
        //   - dropNoProducts([PackageURL])  -- re-consider this
        //   - mergeWithExisting([PackageURL])
        //   - sort
        // - save

        // fetch all dependencies
        let api = SwiftPackageIndexAPI(baseURL: apiBaseURL, apiToken: spiApiToken)
        let packages = try await api.fetchDependencies()
        print("Total packages:", packages.count)

        let missing = packages.missingDependencies()
        print("Not indexed:", missing.count)

        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        defer { try? client.syncShutdown() }

#warning("refactor this with `missingDependencies` above")
        let indexedCanonicalPaths = Set(packages.map(\.url.canonicalPath))
        var newPackages = [PackageURL]()
        for dep in missing {
            // resolve redirects
            print("Processing:", dep.packageURL, "...")
            guard let resolved = await Current.resolvePackageRedirectsAsync(dep.packageURL).url else {
                // TODO: consider adding retry for some errors
                print("  ... redirect resolution returned nil")
                continue
            }
            if resolved.absoluteString != dep.packageURL.absoluteString {
                print("  ... redirected to:", resolved)
            }
            if indexedCanonicalPaths.contains(resolved.canonicalPackageURL.canonicalPath) {
                print("  ... already indexed")
                continue
            }
            // drop forks
            let repo = try await Current.fetchRepositoryAsync(client, resolved)
            guard !repo.fork else {
                print("  ... is fork")
                continue
            }
            // TODO: drop no products?
            newPackages.append(resolved.appendingGitExtension())
            if newPackages.count >= limit {
                print("  ... limit reached.")
                break
            }
        }

        print("New packages:", newPackages.count)

        // merge with existing and sort result
        let input = packages.map { $0.url.packageURL }
        let merged = newPackages.mergingWithExisting(urls: input)
            .sorted(by: { $0.lowercased() < $1.lowercased() })

        print("Total:", merged.count)

#warning("load and merge package file")
    }

    public init() { }

}


extension [SwiftPackageIndexAPI.PackageRecord] {
    func missingDependencies() -> Set<TransformedHashable<CanonicalPackageURL, String>> {
        let indexedPaths = Set(map(\.url.canonicalPath))
        let all = flatMap { $0.resolvedDependencies ?? [] }
        return Set(all
            .filter { !indexedPaths.contains($0.canonicalPath) }
            .map { TransformedHashable($0, transform: \.canonicalPath) }
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
