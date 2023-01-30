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

import XCTest

@testable import ValidatorCore


final class CacheTests: XCTestCase {

    func test_load() throws {
        // setup
        let cacheFilename = "cache"
        Current.fileManager.fileExists = { _ in true }
        Current.fileManager.contents = { fname in
            if fname == cacheFilename {
                let cache = [ Cache<Int>.Key(string: "0"): try! JSONEncoder().encode(0) ]
                return try? JSONEncoder().encode(cache)
            } else {
                return nil
            }
        }

        // MUT
        let cache = Cache<Int>.load(from: cacheFilename)

        // validate
        XCTAssertEqual(cache[.init(string: "0")], 0)
    }

}
