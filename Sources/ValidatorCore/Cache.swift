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


struct Cache<T: Codable> {
    struct Key: Codable, Hashable, CustomStringConvertible {
        let string: String

        init(string: String) {
            self.string = string.lowercased()
        }

        var description: String { string }
    }

    var data: [Key: Data] = [:]

    subscript(key: Key) -> T? {
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


extension Cache {

    static func load(from cachePath: String) -> Self {
        if Current.fileManager.fileExists(cachePath) {
            if let contents = Current.fileManager.contents(cachePath),
               let data = try? JSONDecoder().decode([Key: Data].self, from: contents) {
                return .init(data: data)
            }
        }
        return .init(data: [:])
    }

    func save(to cachePath: String) throws {
        let contents = try JSONEncoder().encode(data)
        try Current.fileManager.write(contents, cachePath)
    }

}
