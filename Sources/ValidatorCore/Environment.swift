import Foundation


struct Environment {
    var fileManager: FileManager
}


extension Environment {
    static let live: Self = .init(
        fileManager: .live
    )
}


struct FileManager {
//    var contents: (_ atPath: String) -> Data?
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
//        contents: Foundation.FileManager.default.contents(atPath:),
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
