import ArgumentParser
import Foundation
import Tagged


typealias PackageURL = Tagged<Package, URL>


extension PackageURL {
    var absoluteString: String { rawValue.absoluteString }
    var host: String? { rawValue.host }
    var scheme: String? { rawValue.scheme }
    var repository: String { rawValue.deletingGitExtension().lastPathComponent }
    var owner: String { rawValue.deletingLastPathComponent().lastPathComponent }

    func appendingGitExtension() -> Self {
        if rawValue.pathExtension.lowercased() == "git" { return self }
        let url = URL(string: absoluteString
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/")))!
            .appendingPathExtension("git")
        return Self(rawValue: url)
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
    /// Merge package URLs with list of existing package URLs, giving the existing package urls priority, in order to preserve their capitalisation.
    /// - Parameter urls: existing package URLs
    /// - Returns: updated list of package URLs
    func mergingWithExisting(urls: [PackageURL]) -> Self {
        var result = urls
        var seen = Set(urls.map { $0.normalized() })
        forEach { url in
            if seen.insert(url.normalized()).inserted {
                result.append(url)
            }
        }
        return result
    }
}
