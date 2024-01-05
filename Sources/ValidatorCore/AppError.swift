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


enum AppError: Error {
    case decodingError(context: String, underlyingError: Error, json: String)
    case dumpPackageError(String)
    case githubTokenNotSet
    case invalidPackage(url: PackageURL)
    case invalidDenyListUrl(string: String)
    case ioError(String)
    case manifestNotFound(owner: String, name: String)
    case noData(URL)
    case rateLimited(until: Date)
    case repositoryNotFound(owner: String, name: String)
    case requestFailed(URL, UInt)
    case retryLimitExceeded
    case runtimeError(String)
}
