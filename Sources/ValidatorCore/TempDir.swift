import Foundation


enum TempDirError: LocalizedError {
    case invalidPath(String)
}


class TempDir {
    let path: String

    init() throws {
        let tempDir = Current.fileManager.temporaryDirectory()
            .appendingPathComponent(UUID().uuidString)
        path = tempDir.path
        try Current.fileManager.createDirectory(path, true, nil)
        precondition(Current.fileManager.fileExists(path), "failed to create temp dir")
    }

    deinit {
        do {
            try Current.fileManager.removeItem(path)
        } catch {
            print("⚠️ failed to delete temp directory: \(error.localizedDescription)")
        }
    }

}


func withTempDir<T>(body: (String) throws -> T) throws -> T {
    let tmp = try TempDir()
    return try body(tmp.path)
}
