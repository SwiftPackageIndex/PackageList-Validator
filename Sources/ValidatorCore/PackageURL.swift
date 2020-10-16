import ArgumentParser
import Foundation
import Tagged


typealias PackageURL = Tagged<Package, URL>


extension PackageURL {
    var absoluteString: String { rawValue.absoluteString }
    var host: String? { rawValue.host }
    var scheme: String? { rawValue.scheme }
    var repository: String { rawValue.deletingPathExtension().lastPathComponent }
    var owner: String { rawValue.deletingLastPathComponent().lastPathComponent }

    func addingGitExtension() -> Self {
        guard !absoluteString.hasSuffix(".git") else { return self }
        return Self(rawValue: rawValue.appendingPathExtension("git"))
    }

    func deletingGitExtension() -> Self {
        guard absoluteString.hasSuffix(".git") else { return self }
        let url = URL(string: absoluteString.deletingGitExtension())!
        return Self(rawValue: url)
    }

    func lowercased() -> String {
        absoluteString.lowercased()
    }

    func normalized() -> String {
        let str = lowercased()
        return str.hasSuffix(".git") ? str : str + ".git"
    }
}


extension PackageURL: ExpressibleByArgument {
    public init?(argument: String) {
        guard let url = URL(string: argument) else { return nil }
        self.init(rawValue: url)
    }
}


extension Array where Element == PackageURL {
    func deletingDuplicates() -> Self {
        var seen: [String] = []
        var toDelete: [Index] = []
        enumerated().forEach { (idx, url) in
            let normalized = url
                .deletingGitExtension().lowercased()
            if seen.contains(normalized) {
                toDelete.append(idx)
            } else {
                seen.append(normalized)
            }
        }
        return enumerated().filter { (idx, _) in
            !toDelete.contains(idx)
        }
        .map { $0.1 }
    }
}
