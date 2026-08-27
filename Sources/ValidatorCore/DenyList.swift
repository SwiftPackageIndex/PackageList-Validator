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


// The packages we will not index.
struct DenyList {
    static let empty = Self(urls: [])

    private let denied: Set<CaseInsensitivePackageURL>

    init(urls: [PackageURL]) {
        denied = Set(urls.map(CaseInsensitivePackageURL.init))
    }

    static func load(from path: String) throws -> Self {
        struct DeniedPackage: Decodable {
            var packageUrl: String

            enum CodingKeys: String, CodingKey {
                case packageUrl = "package_url"
            }
        }

        guard let data = Current.fileManager.contents(path) else {
            throw AppError.ioError("could not read deny list at \(path)")
        }
        let denied = try JSONDecoder().decode([DeniedPackage].self, from: data)
        return .init(urls: try denied.map {
            guard let url = URL(string: $0.packageUrl) else {
                throw AppError.invalidDenyListUrl(string: $0.packageUrl)
            }
            return PackageURL(rawValue: url)
        })
    }

    func contains(_ url: PackageURL) -> Bool {
        denied.contains(.init(url))
    }

    func excluding(_ packages: [PackageURL]) -> [PackageURL] {
        Array(Set(packages.map(CaseInsensitivePackageURL.init)).subtracting(denied))
            .map(\.value)
            .sorted()
    }
}
