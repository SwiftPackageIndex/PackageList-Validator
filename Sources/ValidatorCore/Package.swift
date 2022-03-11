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

import AsyncHTTPClient
import Foundation
import NIO
import ShellOut
import Tagged


struct Package: Codable {
    var name: String
    var products: [Product]
    var dependencies: [Dependency]
    var toolsVersion: ToolsVersion?

    struct Product: Codable {
        var name: String
    }

    struct Dependency: Codable, Hashable {
        var scm: [SCM]?

        struct SCM: Codable, Hashable {
            var location: PackageURL
        }
    }

    struct ToolsVersion: Codable {
        var _version: String
    }
}


extension Package {

    static var packageDumpCache = Cache<Package>()

    static func decode(from manifestURL: ManifestURL) throws -> Package {
        if let cached = packageDumpCache[Cache.Key(string: manifestURL.rawValue.absoluteString)] {
            return cached
        }
        return try withTempDir { tempDir in
            let fileURL = URL(fileURLWithPath: tempDir).appendingPathComponent("Package.swift")
            let data = try Data(contentsOf: manifestURL.rawValue)
            guard Current.fileManager.createFile(fileURL.path, data, nil) else {
                throw AppError.dumpPackageError("failed to save manifest \(manifestURL.rawValue.absoluteString) to temp directory \(fileURL.absoluteString)")
            }
            do {
                guard let pkgJSON = try Current.shell.run(command: .packageDump, at: tempDir)
                        .data(using: .utf8) else {
                    throw AppError.dumpPackageError("package dump did not return data")
                }
                let pkg = try JSONDecoder().decode(Package.self, from: pkgJSON)
                packageDumpCache[Cache.Key(string: manifestURL.rawValue.absoluteString)] = pkg
                return pkg
            } catch let error as ShellOutError {
                throw AppError.dumpPackageError("package dump failed: \(error.message)")
            }
        }
    }

}


extension Package {

    enum Manifest {}
    typealias ManifestURL = Tagged<Manifest, URL>

    static func getManifestURL(client: HTTPClient, packageURL: PackageURL) -> EventLoopFuture<ManifestURL> {
        Current.fetchRepository(client, packageURL.owner, packageURL.repository)
            .map(\.default_branch)
            .map { defaultBranch in
                URL(string: "https://raw.githubusercontent.com/\(packageURL.owner)/\(packageURL.repository)/\(defaultBranch)/Package.swift")!
            }
            .map(ManifestURL.init(rawValue:))
    }

}
