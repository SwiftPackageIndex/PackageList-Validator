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

extension Validator {
    struct ApplyDenyList: ParsableCommand {
        @Option(name: .shortAndLong, help: "Path to packages.json")
        var packagesFile: String

        @Option(name: .shortAndLong, help: "Path to denylist.json")
        var denyFile: String

        private struct DeniedPackage: Decodable {
            var packageUrl: String

            enum CodingKeys: String, CodingKey {
                case packageUrl = "package_url"
            }
        }

        func getDenyListUrls(from path: String) throws -> [PackageURL] {
            let fileUrl = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: fileUrl)
            let deniedPackages = try JSONDecoder().decode([DeniedPackage].self, from: data)
            return try deniedPackages.map { deniedPackage in
                guard let url = URL(string: deniedPackage.packageUrl)
                else { throw AppError.invalidDenyListUrl(string: deniedPackage.packageUrl)}

                return PackageURL(rawValue: url)
            }
        }

        func processPackageDenyList(packageList: [PackageURL], denyList: [PackageURL]) -> [PackageURL] {
            // Note: If the implementation of this function ever changes, `processPackageDenyList`
            // in the Server project will also need updating to match.

            struct CaseInsensitivePackageURL: Equatable, Hashable {
                var url: PackageURL

                init(_ url: PackageURL) {
                    self.url = url
                }

                func hash(into hasher: inout Hasher) {
                    hasher.combine(url.absoluteString.lowercased())
                }

                static func == (lhs: Self, rhs: Self) -> Bool {
                    lhs.url.absoluteString.lowercased() == rhs.url.absoluteString.lowercased()
                }
            }

            return Array(
                Set(packageList.map(CaseInsensitivePackageURL.init))
                    .subtracting(Set(denyList.map(CaseInsensitivePackageURL.init)))
            ).map(\.url).sorted { $0.absoluteString.lowercased() < $1.absoluteString.lowercased() }
        }

        var packageListEncoder: JSONEncoder {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes, .prettyPrinted]
            return encoder
        }

        mutating func run() throws {
            let packageUrls = try InputSource.file(packagesFile).packageURLs()
            let denyListUrls = try getDenyListUrls(from: denyFile)
            let processedPackageList = processPackageDenyList(packageList: packageUrls, denyList: denyListUrls)

            let fileURL = URL(fileURLWithPath: packagesFile)
            try packageListEncoder.encode(processedPackageList).write(to: fileURL)
        }
    }
}

