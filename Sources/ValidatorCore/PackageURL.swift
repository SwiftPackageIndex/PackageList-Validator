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
import Tagged


typealias PackageURL = Tagged<Package, URL>


extension PackageURL {
    var absoluteString: String { rawValue.absoluteString }
    var host: String? { rawValue.host }
    var scheme: String? { rawValue.scheme }
    var repository: String { rawValue.deletingGitExtension().lastPathComponent }
    var owner: String { rawValue.deletingLastPathComponent().lastPathComponent }

    func appendingGitExtension() -> Self {
        if rawValue.pathExtension.lowercased() == "git" { return self }
        let url = URL(string: absoluteString
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/")))!
            .appendingPathExtension("git")
        return Self(rawValue: url)
    }

    func deletingGitExtension() -> Self {
        guard absoluteString.hasSuffix(".git") else { return self }
        let url = URL(string: absoluteString.deletingGitExtension())!
        return Self(rawValue: url)
    }

    func lowercased() -> String {
        absoluteString.lowercased()
    }

    func normalized() -> String {
        let str = lowercased()
        return str.hasSuffix(".git") ? str : str + ".git"
    }
}


extension PackageURL: ExpressibleByArgument {
    public init?(argument: String) {
        guard let url = URL(string: argument) else { return nil }
        self.init(rawValue: url)
    }
}


extension Array where Element == PackageURL {
    /// Merge package URLs with list of existing package URLs, giving the existing package urls priority, in order to preserve their capitalisation.
    /// - Parameter urls: existing package URLs
    /// - Returns: updated list of package URLs
    func mergingWithExisting(urls: [PackageURL]) -> Self {
        var seen = Set<String>()
        return (urls + self).compactMap {
            seen.insert($0.normalized()).inserted ? $0 : nil
        }
    }
}
