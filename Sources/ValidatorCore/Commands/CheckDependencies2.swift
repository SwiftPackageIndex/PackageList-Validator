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
import CanonicalPackageURL


public struct CheckDependencies2: AsyncParsableCommand {
    @Option(name: .long)
    var apiBaseURL: String = "https://swiftpackageindex.com"

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
        let dependencies = try await api.fetchDependencies()
        print("Dependencies:", dependencies.count)

        let missing = dependencies.missingDependencies()
        print("Not indexed:", missing.count)

        // resolve redirects
        _ = missing.prefix(10)
            .map {
                print($0.canonicalPath)
            }
    }

    public init() { }

}


extension [SwiftPackageIndexAPI.PackageRecord] {
#warning("add test")
    func missingDependencies() -> [CanonicalPackageURL] {
        let indexedPaths = Set(map(\.url.canonicalPath))
        let all = flatMap { $0.resolvedDependencies ?? [] }
        return all.filter { !indexedPaths.contains($0.canonicalPath) }
    }
}
