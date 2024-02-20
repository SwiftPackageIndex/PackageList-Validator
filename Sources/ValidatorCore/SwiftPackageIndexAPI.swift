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


import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import CanonicalPackageURL


public struct SwiftPackageIndexAPI {
    var baseURL: String
    var apiToken: String

    public init(baseURL: String, apiToken: String) {
        self.baseURL = baseURL
        self.apiToken = apiToken
    }

    struct Error: Swift.Error {
        var message: String
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension SwiftPackageIndexAPI {
    struct PackageRecord: Codable, Equatable {
        var id: UUID
        var url: CanonicalPackageURL
        var resolvedDependencies: [CanonicalPackageURL]?
    }

    func fetchDependencies() async throws -> [PackageRecord] {
        let url = URL(string: "\(baseURL)/api/dependencies")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        assert((response as? HTTPURLResponse)?.statusCode == 200,
               "expected 200, received \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
        return try Self.decoder.decode([PackageRecord].self, from: data)
    }
}
