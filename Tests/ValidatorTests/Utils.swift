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


func fixtureData(for fixture: String) throws -> Data {
    try Data(contentsOf: fixtureUrl(for: fixture))
}


func fixtureUrl(for fixture: String) -> URL {
    fixturesDirectory().appendingPathComponent(fixture)
}


func fixturesDirectory(path: String = #file) -> URL {
    let url = URL(fileURLWithPath: path)
    let testsDir = url.deletingLastPathComponent()
    return testsDir.appendingPathComponent("Fixtures")
}


// MARK: - Extension helpers

@testable import ValidatorCore

extension Package {
    static func mock(dependencyURLs: [PackageURL]) -> Self {
        .init(name: "",
              products: [.mock],
              dependencies: dependencyURLs.map { .init(location: $0) } )
    }
}


extension Package.Product {
    static let mock: Self = .init(name: "product")
}


extension Array where Element == String {
    var asURLs: [PackageURL] {
        compactMap(URL.init(string:))
            .map(PackageURL.init(rawValue:))
    }
}


extension Package.ManifestURL {
    init(_ urlString: String) {
        self.init(rawValue: URL(string: urlString)!)
    }
}


extension Package.Dependency {
    init(location: PackageURL) {
        self.init(sourceControl: [
            .init(location: .init(remote: [.init(packageURL: location)]))
        ])
    }
}
