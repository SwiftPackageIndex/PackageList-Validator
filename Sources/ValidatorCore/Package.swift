import AsyncHTTPClient
import Foundation
import NIO
import ShellOut
import Tagged


struct Package: Codable {
    let name: String
    let products: [Product]
    let dependencies: [Dependency]

    struct Product: Codable {
        let name: String
    }

    struct Dependency: Codable, Hashable {
        let name: String
        let url: PackageURL
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
