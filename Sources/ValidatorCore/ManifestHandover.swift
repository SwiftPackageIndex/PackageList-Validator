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


// The directory check-dependencies fetches manifests into for PackageList's .github/evaluate_manifests.sh to evaluate.
//
// The filesystem layout is API: one directory per package, `manifests/` for the
// Package*.swift files and `url` for the package they came from. The script mounts `manifests` and
// nothing else, so `url` and the markers stay outside it, out of reach of the code being evaluated.
//
//   <root>/<slug>/manifests/Package*.swift
//   <root>/<slug>/url
//   <root>/<slug>/failed        written by the script when the manifests did not load
//   <root>/evaluated            written by the script once it has run
struct ManifestHandover {
    var root: String

    // A handover with no sign off means nothing was evaluated, which has to be an error rather
    // than a run in which nothing failed; otherwise every unevaluated candidate gets added.
    static let evaluatedMarker = "evaluated"
    static let failedMarker = "failed"

    func prepare(slug: String, url: PackageURL) throws -> String {
        try validate(slug: slug)
        let manifests = path(slug, "manifests")
        try Current.fileManager.createDirectory(manifests, true, nil)
        guard Current.fileManager.createFile(path(slug, "url"), Data(url.absoluteString.utf8), nil) else {
            throw AppError.ioError("failed to write url for \(slug) in \(root)")
        }
        return manifests
    }

    func validatedURLs() throws -> [PackageURL] {
        guard Current.fileManager.fileExists(path(Self.evaluatedMarker)) else {
            throw AppError.runtimeError(
                "\(root) has no '\(Self.evaluatedMarker)' marker - its manifests were never evaluated"
            )
        }
        return try Current.fileManager.contentsOfDirectory(root)
            .filter { Current.fileManager.fileExists(path($0, "manifests")) }
            .filter { !Current.fileManager.fileExists(path($0, Self.failedMarker)) }
            .map(packageURL(slug:))
    }

    func discard(slug: String) throws {
        try validate(slug: slug)
        try Current.fileManager.removeItem(path(slug))
    }

    func packageURL(slug: String) throws -> PackageURL {
        guard let data = Current.fileManager.contents(path(slug, "url")),
              let url = URL(string: String(decoding: data, as: UTF8.self)
                  .trimmingCharacters(in: .whitespacesAndNewlines))
        else { throw AppError.runtimeError("no readable url for \(slug) in \(root)") }
        return .init(rawValue: url)
    }

    // A slug names a directory we create, and it is built from what the GitHub API told us the
    // repository is called. Valid characters for repo names are alphanumerics, hyphens, underscores
    // and dots.
    private func validate(slug: String) throws {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_."))
        guard !slug.isEmpty,
              slug.first != ".",
              slug.unicodeScalars.allSatisfy(allowed.contains)
        else { throw AppError.runtimeError("'\(slug)' is not usable as a handover directory name") }
    }

    func path(_ components: String...) -> String {
        components.reduce(URL(fileURLWithPath: root)) { $0.appendingPathComponent($1) }.path
    }
}


extension Github.Repository {
    // GitHub logins contain no underscore, so the first one always splits owner from name and two
    // repositories cannot collide onto a single directory.
    var handoverSlug: String { "\(owner.login)_\(name)" }
}
