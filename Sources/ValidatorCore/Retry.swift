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


enum Retry {
    static func backedOffDelay(baseDelay: Double, tryCount: Int) -> UInt32 {
        (pow(2, max(0, tryCount - 1)) * Decimal(baseDelay) as NSDecimalNumber).uint32Value
    }

    static func attempt<T>(_ label: String,
                           delay: Double = 5,
                           retries: Int = 5,
                           _ block: () throws -> T) throws -> T {
        var retriesLeft = retries
        var currentTry = 1
        while true {
            if currentTry > 1 {
                print("\(label) (attempt \(currentTry))")
            }
            do {
                return try block()
            } catch let AppError.invalidPackage(url) {
                throw AppError.invalidPackage(url: url)
            } catch {
                guard retriesLeft > 0 else { break }
                let delay = backedOffDelay(baseDelay: delay, tryCount: currentTry)
                print("Retrying in \(delay) seconds ...")
                sleep(delay)
                currentTry += 1
                retriesLeft -= 1
            }
        }
        throw AppError.retryLimitExceeded
    }
}
