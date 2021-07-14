// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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


struct Cache<T: Codable> {
    struct Key<T: Codable>: Hashable, CustomStringConvertible {
        let string: String

        var description: String {
            "[\(T.self) \(string)]"
        }
    }
    var data: [Key<T>: Data] = [:]

    subscript(key: Key<T>) -> T? {
        get {
            if let data = data[key] {
                // print("Cache hit: \(key)")
                return try? JSONDecoder().decode(T.self, from: data)
            }
            return nil
        }
        set {
            data[key] = try! JSONEncoder().encode(newValue)
        }
    }
}
