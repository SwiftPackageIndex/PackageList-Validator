import ArgumentParser
import Foundation


extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(string: argument)
    }
}


extension URL {
    func addingGitExtension() -> URL {
        guard !absoluteString.hasSuffix(".git") else { return self }
        return appendingPathExtension("git")
    }

    func deletingGitExtension() -> URL {
        guard absoluteString.hasSuffix(".git") else { return self }
        return URL(string: absoluteString.deletingGitExtension())!
    }

    func normalized() -> String {
        let str = absoluteString.lowercased()
        return str.hasSuffix(".git") ? str : str + ".git"
    }
}
