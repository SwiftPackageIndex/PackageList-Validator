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


extension FileManager {
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
