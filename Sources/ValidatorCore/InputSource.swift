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


enum InputSource {
    case file(String)
    case invalid
    case packageList
    case packageURLs([PackageURL])

    // Commands taking either --input or a list of package URLs, but not both, resolve which one
    // they were given this way.
    init(input: String?, packageURLs: [PackageURL]) {
        switch (input, packageURLs.count) {
            case (.some(let fname), 0):
                self = .file(fname)
            case (.none, 1...):
                self = .packageURLs(packageURLs)
            default:
                self = .invalid
        }
    }

    func packageURLs() throws -> [PackageURL] {
        switch self {
            case .file(let path):
                let fileURL = URL(fileURLWithPath: path)
                return try JSONDecoder().decode([PackageURL].self,
                                                from: Data(contentsOf: fileURL))
            case .invalid:
                throw AppError.runtimeError("invalid input source")
            case .packageList:
                return try Github.packageList()
            case .packageURLs(let urls):
                return urls
        }
    }
}
