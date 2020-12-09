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

    func addingGitExtension() -> Self {
        guard !absoluteString.hasSuffix(".git") else { return self }
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

    /// Merge elements with given urls, adding any new ones. Comparison is made between normalised urls.
    /// - Parameter urls: canonical list of urls
    func mergingAdditions(with urls: [PackageURL]) -> Self {
        var result = urls
        var seen = Set(urls.map(\.absoluteString) + urls.map { $0.normalized() })
        forEach { url in
            let normalized = url.normalized()
            if !seen.contains(normalized) {
                result.append(url)
                seen.insert(url.absoluteString)
                seen.insert(normalized)
            }
        }
        return result
    }

}
