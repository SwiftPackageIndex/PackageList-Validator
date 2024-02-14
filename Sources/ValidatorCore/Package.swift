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
        var sourceControl: [SourceControl]?

        var firstRemote: PackageURL? { sourceControl?.first?.location.remote.first?.packageURL }

        struct SourceControl: Codable, Hashable {
            var location: Location

            struct Location: Codable, Hashable {
                var remote: [Remote]

                struct Remote: Codable, Hashable {
                    var packageURL: PackageURL

                    init(packageURL: PackageURL) {
                        self.packageURL = packageURL
                    }

                    enum CodingKeys: String, CodingKey {
                        case packageURL = "urlString"
                    }
                    
                    init(from decoder: Decoder) throws {
                        do {
                            // try and decode {"urlString": "..."}
                            let container = try decoder.container(keyedBy: CodingKeys.self)
                            self.packageURL = try container.decode(PackageURL.self, forKey: CodingKeys.packageURL)
                        } catch {
                            // try and decode plain "..."
                            let container = try decoder.singleValueContainer()
                            let urlString = try container.decode(String.self)
                            guard let url = URL(string: urlString) else {
                                throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath,
                                                                        debugDescription: "invalid url"))
                            }
                            self.packageURL = .init(rawValue: url)
                        }
                    }
                }
            }
        }
    }

    struct ToolsVersion: Codable {
        var _version: String
    }
}


extension Package {

    static var packageDumpCache = Cache<Package>()

    static var cacheFilename: String { ".packageDumpCache" }
    static func loadPackageDumpCache() { packageDumpCache = .load(from: cacheFilename) }
    static func savePackageDumpCache() throws { try packageDumpCache.save(to: cacheFilename) }

    static func decode(client: HTTPClient, repository: Github.Repository) async throws -> Self {
        let cacheKey = repository.path
        if let cached = packageDumpCache[Cache.Key(string: cacheKey)] {
            return cached
        }
        return try await withTempDir { tempDir in
            for manifestURL in try await Package.getManifestURLs(client: client, repository: repository) {
                let fileURL = URL(fileURLWithPath: tempDir).appendingPathComponent(manifestURL.lastPathComponent)
                let data = try Data(contentsOf: manifestURL.rawValue)
                guard Current.fileManager.createFile(fileURL.path, data, nil) else {
                    throw AppError.dumpPackageError("failed to save manifest \(manifestURL.rawValue.absoluteString) to temp directory \(fileURL.absoluteString)")
                }
            }
            do {
                guard let pkgJSON = try Current.shell.run(command: .packageDump, at: tempDir)
                        .data(using: .utf8) else {
                    throw AppError.dumpPackageError("package dump did not return data")
                }
                let pkg = try JSONDecoder().decode(Package.self, from: pkgJSON)
                packageDumpCache[Cache.Key(string: cacheKey)] = pkg
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

    static func getManifestURLs(client: HTTPClient, repository: Github.Repository) async throws -> [ManifestURL] {
        let manifestFiles = try await Github.listRepositoryFilePaths(client: client, repository: repository)
          .filter { $0.hasPrefix("Package") }
          .filter { $0.hasSuffix(".swift") }
          .sorted()
        guard !manifestFiles.isEmpty else { throw AppError.manifestNotFound(owner: repository.owner.login, name: repository.name) }
        return manifestFiles
            .map { URL(string: "https://raw.githubusercontent.com/\(repository.path)/\(repository.defaultBranch)/\($0)")! }
            .map(ManifestURL.init(rawValue:))
    }

}
