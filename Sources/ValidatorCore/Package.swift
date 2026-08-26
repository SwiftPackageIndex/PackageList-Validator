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

    // Fetches the package's manifests into `directory` for evaluate_manifests.sh to evaluate.
    // It deliberately does not evaluate them: that runs third party code, which belongs in the
    // script's container rather than in this process, which holds tokens and has a network.
    static func fetchManifests(client: Client, repository: Github.Repository, into directory: String) async throws {
        for manifestURL in try await Package.getManifestURLs(client: client, repository: repository) {
            let name = manifestURL.rawValue.lastPathComponent
            guard isManifestFilename(name) else {
                throw AppError.dumpPackageError("refusing to write manifest named '\(name)' from \(repository.path)")
            }
            let fileURL = URL(fileURLWithPath: directory).appendingPathComponent(name)
            let buffer = try await Current.fetch(client, manifestURL.rawValue).get()
            guard let data = buffer.getData(at: 0, length: buffer.readableBytes) else {
                throw AppError.dumpPackageError("failed to get data for manifest \(manifestURL.rawValue.absoluteString)")
            }
            guard Current.fileManager.createFile(fileURL.path, data, nil) else {
                throw AppError.dumpPackageError("failed to save manifest \(manifestURL.rawValue.absoluteString) to \(fileURL.absoluteString)")
            }
        }
    }

    // The manifest list comes from the repository being validated, so it is attacker controlled.
    // A manifest is a single path component named Package*.swift and nothing else.
    static func isManifestFilename(_ name: String) -> Bool {
        name.hasPrefix("Package") && name.hasSuffix(".swift")
            && !name.contains("/") && !name.contains("\u{0}")
    }

}


extension Package {

    enum Manifest {}
    typealias ManifestURL = Tagged<Manifest, URL>

    static func getManifestURLs(client: Client, repository: Github.Repository) async throws -> [ManifestURL] {
        // Filtering the whole path would also match `Packages/Package.swift`, which is not this
        // package's manifest and which collides with the real one once we write it out by name.
        let manifestFiles = try await Github.listRepositoryFilePaths(client: client, repository: repository)
          .filter { !$0.contains("/") }
          .filter { $0.hasPrefix("Package") }
          .filter { $0.hasSuffix(".swift") }
          .sorted()
        guard !manifestFiles.isEmpty else { throw AppError.manifestNotFound(owner: repository.owner.login, name: repository.name) }
        return manifestFiles
            .map { URL(string: "https://raw.githubusercontent.com/\(repository.path)/\(repository.defaultBranch)/\($0)")! }
            .map(ManifestURL.init(rawValue:))
    }

}
