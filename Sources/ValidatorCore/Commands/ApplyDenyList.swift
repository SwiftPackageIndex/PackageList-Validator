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

        var packageListEncoder: JSONEncoder {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes, .prettyPrinted]
            return encoder
        }

        mutating func run() throws {
            let packageUrls = try InputSource.file(packagesFile).packageURLs()
            let processedPackageList = try DenyList.load(from: denyFile).excluding(packageUrls)

            let fileURL = URL(fileURLWithPath: packagesFile)
            try packageListEncoder.encode(processedPackageList).write(to: fileURL)
        }
    }
}

