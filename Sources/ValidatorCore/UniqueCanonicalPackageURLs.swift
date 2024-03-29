// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import CanonicalPackageURL


typealias HashedCanonicalPackageURL = TransformedHashable<CanonicalPackageURL, String>

extension HashedCanonicalPackageURL {
    init(_ url: CanonicalPackageURL) {
        self.init(url, transform: \.canonicalPath)
    }
}


typealias UniqueCanonicalPackageURLs = Set<HashedCanonicalPackageURL>


extension UniqueCanonicalPackageURLs {
    func contains(_ member: CanonicalPackageURL) -> Bool {
        contains(.init(member, transform: \.canonicalPath))
    }

    @discardableResult
    mutating func insert(_ newMember: CanonicalPackageURL) -> (inserted: Bool, memberAfterInsert: CanonicalPackageURL) {
        let res = insert(.init(newMember, transform: \.canonicalPath))
        return (res.inserted, res.memberAfterInsert.value)
    }

    init(_ urls: [PackageURL]) {
        self = Set(urls.map(\.canonicalPackageURL).map { .init($0, transform: \.canonicalPath) })
    }

    func sorted() -> [PackageURL] {
        map(\.packageURL).sorted()
    }
}


extension [PackageURL] {
    func sorted() -> Self {
        sorted(by: { $0.lowercased() < $1.lowercased() })
    }
}
