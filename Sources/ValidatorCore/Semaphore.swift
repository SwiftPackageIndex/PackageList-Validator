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
#if os(Linux)
import CDispatch // for NSEC_PER_SEC https://github.com/apple/swift-corelibs-libdispatch/issues/659
#endif


actor Semaphore {
    var current = 0
    var maximum: Int
    var granularity: Double

    init(maximum: Int, granularity: Double = 0.01) {
        self.maximum = maximum
        self.granularity = granularity
    }

    var unavailable: Bool { current > maximum }

    func increment() { current += 1 }
    func decrement() { current -= 1 }

    func waitForAvailability() async throws {
        while unavailable { try await Task.sleep(nanoseconds: UInt64(granularity * Double(NSEC_PER_SEC))) }
    }
}
