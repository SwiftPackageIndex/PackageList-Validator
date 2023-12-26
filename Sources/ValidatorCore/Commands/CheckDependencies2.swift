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

        // resolve redirects
        var newPackages = [PackageURL]()
        for dep in missing {
            print("Resolving:", dep.url.canonicalPath)
            guard let resolved = await Current.resolvePackageRedirectsAsync(dep.packageURL).url else { continue }
            newPackages.append(resolved)
            if newPackages.count >= limit { break }
        }

        print("New packages:", newPackages.count)
    }

    public init() { }

}


extension [SwiftPackageIndexAPI.PackageRecord] {
#warning("add test")
    func missingDependencies() -> Set<HashableURL> {
        let indexedPaths = Set(map(\.url.canonicalPath))
        let all = flatMap { $0.resolvedDependencies ?? [] }
        return Set(all
            .filter { !indexedPaths.contains($0.canonicalPath) }
            .map { HashableURL(url: $0) }
        )
    }
}


struct HashableURL {
    var url: CanonicalPackageURL
}

#warning("add test")
extension HashableURL: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url.canonicalPath == rhs.url.canonicalPath
    }
}

#warning("add test")
extension HashableURL: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(url.canonicalPath)
    }
}


extension HashableURL {
    var packageURL: PackageURL {
        .init(url.canonicalURL)
    }
}


extension CanonicalPackageURL {
#warning("move to CanonicalPackageURL package")
    var canonicalURL: URL {
        .init(string: "https://\(hostname)/\(path)")!
    }
}
