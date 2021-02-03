import Foundation


struct FileManager {
    var createDirectory: (_ path: String,
                          _ withIntermediateDirectories: Bool,
                          _ attributes: [FileAttributeKey : Any]?) throws -> Void
    var createFile: (_ atPath: String,
                     _ contents: Data?,
                     _ attributes: [FileAttributeKey : Any]?) -> Bool
    var fileExists: (_ path: String) -> Bool
    var removeItem: (_ path: String) throws -> Void
    var temporaryDirectory: () -> URL
}


extension FileManager {
    static let live: Self = .init(
        createDirectory: Foundation.FileManager.default
            .createDirectory(atPath:withIntermediateDirectories:attributes:),
        createFile: Foundation.FileManager.default.createFile(atPath:contents:attributes:),
        fileExists: Foundation.FileManager.default.fileExists(atPath:),
        removeItem: Foundation.FileManager.default.removeItem(atPath:),
        temporaryDirectory: { Foundation.FileManager.default.temporaryDirectory }
    )

    static let mock: Self = .init(
        createDirectory: { _, _, _ in },
        createFile: { _, _, _ in true },
        fileExists: { _ in true },
        removeItem: { _ in },
        temporaryDirectory: { fatalError("not implemented") }
    )
}


extension FileManager {
    func saveList(_ packages: [PackageURL], path: String) throws {
        let fileURL = URL(fileURLWithPath: path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(packages)
        guard Current.fileManager.createFile(fileURL.path, data, nil) else {
            throw AppError.ioError("failed to save 'packages.json'")
        }
    }
}
