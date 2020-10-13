import Foundation


struct Environment {
    var fileManager: FileManager
    var githubToken: () -> String?
    var shell: Shell
}


extension Environment {
    static let live: Self = .init(
        fileManager: .live,
        githubToken: { ProcessInfo.processInfo.environment["GITHUB_TOKEN"] },
        shell: .live
    )
}


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

    static let live: Self = .init(
        createDirectory: Foundation.FileManager.default
            .createDirectory(atPath:withIntermediateDirectories:attributes:),
        createFile: Foundation.FileManager.default.createFile(atPath:contents:attributes:),
        fileExists: Foundation.FileManager.default.fileExists(atPath:),
        removeItem: Foundation.FileManager.default.removeItem(atPath:),
        temporaryDirectory: { Foundation.FileManager.default.temporaryDirectory }
    )
}


#if DEBUG
var Current: Environment = .live
#else
let Current: Environment = .live
#endif
