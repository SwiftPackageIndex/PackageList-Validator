import AsyncHTTPClient
import Foundation
import NIO


struct Package: Decodable {
    let name: String
    let products: [Product]
    let dependencies: [Dependency]

    struct Product: Decodable {
        let name: String
    }

    struct Dependency: Decodable, Hashable {
        let name: String
        let url: URL
    }
}


extension Package {

    static func decode(from manifestURL: URL) throws -> Package {
        assert(manifestURL.absoluteString.hasSuffix("Package.swift"),
               "manifest URL must end with 'Package.swift', was \(manifestURL.absoluteString)")
        return try withTempDir { tempDir in
            let fileURL = URL(fileURLWithPath: tempDir).appendingPathComponent("Package.swift")
            let data = try Data(contentsOf: manifestURL)
            guard Current.fileManager.createFile(fileURL.path, data, nil) else {
                throw AppError.dumpPackageError("failed to save manifest \(manifestURL.absoluteString) to temp directory \(fileURL.absoluteString)")
            }
            guard let pkgJSON = try Current.shell.run(command: .packageDump, at: tempDir)
                    .data(using: .utf8) else {
                throw AppError.dumpPackageError("package dump did not return data")
            }
            return try JSONDecoder().decode(Package.self, from: pkgJSON)
        }
    }


    static func getManifestURL(client: HTTPClient, url: URL) -> EventLoopFuture<URL> {
        let repository = url.deletingPathExtension().lastPathComponent
        let owner = url.deletingLastPathComponent().lastPathComponent
        return Github.fetchRepository(client: client, owner: owner, repository: repository)
            .map(\.default_branch)
            .map { defaultBranch in
                URL(string: "https://raw.githubusercontent.com/\(owner)/\(repository)/\(defaultBranch)/Package.swift")!
            }
    }

}
