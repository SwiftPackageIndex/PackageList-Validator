import Foundation


extension Array where Element == URL {
    func deletingDuplicates() -> Self {
        var seen: [String] = []
        var toDelete: [Index] = []
        enumerated().forEach { (idx, url) in
            let normalized = url
                .deletingGitExtension().absoluteString.lowercased()
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
