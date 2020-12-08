import Foundation


extension URL {
    func deletingGitExtension() -> URL {
        pathExtension == "git"
            ? deletingPathExtension()
            : self
    }
}
