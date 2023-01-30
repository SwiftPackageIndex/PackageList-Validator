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
