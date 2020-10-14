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
    func saveList(_ packages: [URL], path: String) throws {
        let fileURL = URL(fileURLWithPath: path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(packages)
        guard Current.fileManager.createFile(fileURL.path, data, nil) else {
            throw AppError.ioError("failed to save 'packages.json'")
        }
    }
}
