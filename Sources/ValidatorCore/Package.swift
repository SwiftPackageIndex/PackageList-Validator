import Foundation


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
        try withTempDir { tempDir in
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

}
