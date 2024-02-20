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


#if os(Linux)
enum URLSessionErrors: Error {
    case invalidUrlResponse, missingResponseData
}

extension URLSession {
    func data(for request: URLRequest, delegate: (URLSessionTaskDelegate)? = nil) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let response = response as? HTTPURLResponse else {
                    continuation.resume(throwing: URLSessionErrors.invalidUrlResponse)
                    return
                }
                guard let data = data else {
                    continuation.resume(throwing: URLSessionErrors.missingResponseData)
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await data(for: URLRequest(url: url))
    }
}
#endif
