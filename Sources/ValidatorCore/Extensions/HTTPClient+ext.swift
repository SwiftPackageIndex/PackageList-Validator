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

import AsyncHTTPClient


extension HTTPClient {
    static func with(configuration: Configuration = Configuration(),
                     _ operation: (HTTPClient) async throws -> Void) async throws {
        let client = HTTPClient(eventLoopGroupProvider: .singleton, configuration: configuration)
        do {
            try await operation(client)
            try? await client.shutdown()
        } catch {
            try? await client.shutdown()
            throw error
        }
    }
}
