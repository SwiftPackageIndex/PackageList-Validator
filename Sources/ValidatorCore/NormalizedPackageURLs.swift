actor NormalizedPackageURLs {
    var normalized: Set<String>

    init(inputURLs: [PackageURL]) {
        self.normalized = Set(inputURLs.map { $0.normalized() })
    }

    func contains(_ url: PackageURL) -> Bool {
        normalized.contains(url.normalized())
    }

    func insert(_ url: PackageURL) -> (inserted: Bool, memberAfterInsert: String) {
        normalized.insert(url.normalized())
    }
}
