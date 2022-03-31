// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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


struct MergeLists: ParsableCommand {
    @Argument(help: "A list of package files in JSON format to merge.")
    var files: [String] = []

    @Option(name: .shortAndLong)
    var output: Output = .stdout

    func run() throws {
        let packageURLs = try Self.merge(paths: files)

        try output.process(packageURLs: packageURLs)
    }

    static func merge(paths: [String]) throws -> [String] {
        for path in paths {
            print("Merging \(path)")
        }

        let packageLists = try paths
            .map(URL.init(fileURLWithPath:))
            .map { try Data.init(contentsOf: $0) }
            .map { try JSONDecoder().decode([String].self, from: $0) }

        let result = merge(packageLists)

        print("Number of unique urls: \(result.count)")

        return result
    }

    static func merge(_ packageLists: [String]...) -> [String] {
        merge(packageLists)
    }

    static func merge(_ packageLists: [[String]]) -> [String] {
        var packageURLs = Set<CaseinsensitiveString>()
        for p in packageLists {
            packageURLs.formUnion(p.map(CaseinsensitiveString.init(value:)))
        }
        return packageURLs.sorted().map(\.value)
    }

}


/// String container that compares, sorts, and hashes as if it was lowercased while preserving its original casing.
struct CaseinsensitiveString: Hashable, Comparable {
    var value: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.value.lowercased() == rhs.value.lowercased()
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.value.lowercased() < rhs.value.lowercased()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(value.lowercased())
    }
}
