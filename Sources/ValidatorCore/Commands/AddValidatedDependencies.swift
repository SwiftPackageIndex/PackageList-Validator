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

import ArgumentParser


// The second half of the dependency check. check-dependencies fetched candidate manifests into a
// handover directory and the evaluation step has since decided which of them load. This adds the
// survivors to the package list. It runs no third party code and needs no token.
public struct AddValidatedDependencies: ParsableCommand {
    @Option(name: .shortAndLong, help: "read input URLs from file")
    var input: String?

    @Option(name: .long, help: "directory check-dependencies fetched manifests into, once they have been evaluated")
    var manifestDir: String

    @Option(name: .shortAndLong, help: "save changes to output file")
    var output: String?

    @Argument(help: "package URLs already on the list")
    var packageUrls: [PackageURL] = []

    public func run() throws {
        let packageList = UniqueCanonicalPackageURLs(try inputSource.packageURLs())
        let validated = try ManifestHandover(root: manifestDir).validatedURLs()
        print("Evaluated and loaded:", validated.count)

        var newPackages = UniqueCanonicalPackageURLs()
        for url in validated where !packageList.contains(url.canonicalPackageURL) {
            if newPackages.insert(url.canonicalPackageURL).inserted {
                print("✅ ADD (\(newPackages.count)):", url)
            }
        }

        let merged = (packageList.map(\.packageURL) + newPackages.map(\.packageURL)).sorted()
        print("New packages:", newPackages.count)
        print("Total:", merged.count)

        if let path = output {
            try Current.fileManager.saveList(merged, path: path)
        }
    }

    public init() { }
}


extension AddValidatedDependencies {
    var inputSource: InputSource { .init(input: input, packageURLs: packageUrls) }
}
